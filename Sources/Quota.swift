import Foundation

struct Rate: Decodable {
    let usedPercent: Double?
    let windowMinutes: Int?
    let resetsAt: String?
    let resetDescription: String?
    var remaining: Double? { usedPercent.flatMap { $0.isFinite ? max(0, min(100, 100 - $0)) : nil } }
}
struct Extra: Decodable { let id: String; let title: String; let window: Rate }
struct Usage: Decodable {
    let primary: Rate?
    let secondary: Rate?
    let extraRateWindows: [Extra]?
    let updatedAt: String?
}
struct Payload: Decodable { let usage: Usage? }
struct Meter: Identifiable, Codable {
    var id: String { label }
    let label: String
    let remaining: Double?
    let reset: Date?
    let amount: String?
}
struct QuotaCard: Identifiable, Codable {
    let id: String
    let name: String
    let subtitle: String
    var meters: [Meter] = []
    var totalCredits: String?
    var updated: Date?
    var issue: String?
}
func parseDate(_ value: String?) -> Date? {
    guard let value else { return nil }
    let f = ISO8601DateFormatter()
    if let d = f.date(from: value) { return d }
    f.formatOptions.insert(.withFractionalSeconds)
    return f.date(from: value)
}
func period(_ rate: Rate, fallback: String) -> String {
    switch rate.windowMinutes {
    case 300: return "5 小时"
    case 10080: return "每周"
    case 1440: return "每天"
    case 43200: return "每月"
    case let m? where m > 0 && m % 60 == 0: return "\(m / 60) 小时"
    default: return fallback
    }
}
func meter(_ label: String, _ r: Rate, amount: String? = nil) -> Meter {
    Meter(label: label, remaining: r.remaining, reset: parseDate(r.resetsAt), amount: amount)
}
let providers = [
    QuotaCard(id: "codex", name: "Codex", subtitle: "OpenAI"),
    QuotaCard(id: "antigravity", name: "Antigravity", subtitle: "Gemini · Claude / GPT"),
    QuotaCard(id: "cursor", name: "Grok Bot", subtitle: "独立额度"),
    QuotaCard(id: "workbuddy", name: "WorkBuddy", subtitle: "积分概览")
]
func decodeCard(id: String, data: Data) throws -> QuotaCard {
    var card = providers.first { $0.id == id }!
    let result = try JSONDecoder().decode([Payload].self, from: data)
    guard let usage = result.first?.usage else { throw NSError(domain: "Quota", code: 1) }
    card.updated = parseDate(usage.updatedAt) ?? Date()
    let extras = usage.extraRateWindows ?? []
    switch id {
    case "antigravity":
        let wanted = [("antigravity-quota-summary-gemini-5h", "Gemini · 5 小时"), ("antigravity-quota-summary-gemini-weekly", "Gemini · 每周"), ("antigravity-quota-summary-3p-5h", "Claude/GPT · 5 小时"), ("antigravity-quota-summary-3p-weekly", "Claude/GPT · 每周")]
        for (key, label) in wanted {
            if let extra = extras.first(where: { $0.id == key }) { card.meters.append(meter(label, extra.window)) }
        }
        if card.meters.isEmpty {
            if let r = usage.primary { card.meters.append(meter("Gemini · " + period(r, fallback: "当前额度"), r)) }
            if let r = usage.secondary { card.meters.append(meter("Claude/GPT · " + period(r, fallback: "当前额度"), r)) }
        }
    case "cursor":
        // Never substitute Cursor's overall plan allowance for Grok Bot.
        if let r = extras.first(where: { $0.id == "cursor-grok-bot" })?.window { card.meters = [meter(period(r, fallback: "独立额度"), r)] }
    case "workbuddy":
        if let r = usage.primary {
            let text = r.resetDescription ?? ""
            let amount = text.range(of: #"^[\d,.]+(?=\s*/.*credits left)"#, options: .regularExpression).map { String(text[$0]) + " 积分" }
            let total = text.range(of: #"(?<=/ )([\d,.]+)(?= credits left)"#, options: .regularExpression).map { String(text[$0]) + " 积分" }
            card.totalCredits = total
            card.meters = [meter("可用积分", r, amount: amount)]
        }
    default:
        if let r = usage.primary { card.meters.append(meter(period(r, fallback: "当前额度"), r)) }
        if let r = usage.secondary { card.meters.append(meter(period(r, fallback: "第二额度"), r)) }
    }
    if card.meters.isEmpty { throw NSError(domain: "Quota", code: 2) }
    return card
}

struct FetchResult: Sendable { let data: Data?; let error: String? }
func fetchProvider(_ provider: String) -> FetchResult {
    if ["cursor", "workbuddy"].contains(provider) { return BridgeWorker.shared.request(provider: provider, connect: false) }
    let engine = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/CodexBarCLI").path
    guard FileManager.default.isExecutableFile(atPath: engine) else { return FetchResult(data: nil, error: "内置读取引擎缺失，请重新安装汇芯 Token 管家") }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: engine)
    process.arguments = ["usage", "--provider", provider, "--json", "--web-timeout", "20"]
    var env = ProcessInfo.processInfo.environment
    env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (env["PATH"] ?? "")
    process.environment = env
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    do { try process.run() } catch { return FetchResult(data: nil, error: "读取引擎无法启动") }
    // Drain output while running, so large responses cannot deadlock the pipe.
    let watchdog = DispatchWorkItem { if process.isRunning { process.terminate() } }
    DispatchQueue.global().asyncAfter(deadline: .now() + 40, execute: watchdog)
    let kill = DispatchWorkItem { if process.isRunning { Darwin.kill(process.processIdentifier, SIGKILL) } }
    DispatchQueue.global().asyncAfter(deadline: .now() + 43, execute: kill)
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    watchdog.cancel(); kill.cancel()
    guard process.terminationStatus == 0 else {
        let errorText = String(decoding: data, as: UTF8.self).lowercased()
        let needsConnection = errorText.contains("keychain") || errorText.contains("cookie access")
        return FetchResult(data: nil, error: needsConnection ? "需要连接浏览器，请点“连接与来源”" : "暂时无法读取，请检查原工具登录状态")
    }
    return FetchResult(data: data, error: nil)
}

// Only invoked by the user's explicit Connect Browser button; automatic refresh never opens an authorization prompt.
func connectBrowser(_ provider: String) -> FetchResult {
    BridgeWorker.shared.request(provider: provider, connect: true)
}
