import Foundation

struct Rate: Decodable {
    let isSyntheticPlaceholder: Bool?
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
struct Payload: Decodable { let usage: Usage?; let predictions: [String: QuotaForecast]? }
struct Meter: Identifiable, Codable {
    var id: String { label }
    let label: String
    let remaining: Double?
    let reset: Date?
    let amount: String?
    var forecast: QuotaForecast? = nil
}
enum ConnectionIssueKind: String, Codable, Sendable {
    case keychainPermission
    case sessionExpired
    case generic
}
struct QuotaCard: Identifiable, Codable {
    let id: String
    var name: String
    var subtitle: String
    var meters: [Meter] = []
    var totalCredits: String?
    var updated: Date?
    var issue: String?
    var connectionIssue: ConnectionIssueKind? = nil
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
    QuotaCard(id: "workbuddy", name: "WorkBuddy", subtitle: "积分概览")
]
func decodeCard(id: String, data: Data) throws -> QuotaCard {
    guard var card = providers.first(where: { $0.id == id }) else { throw NSError(domain: "Quota", code: 3) }
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
            if let r = usage.primary, r.isSyntheticPlaceholder != true { card.meters.append(meter("Gemini · " + period(r, fallback: "当前额度"), r)) }
            if let r = usage.secondary, r.isSyntheticPlaceholder != true { card.meters.append(meter("Claude/GPT · " + period(r, fallback: "当前额度"), r)) }
        }
    case "cursor":
        // Never substitute Cursor's overall plan allowance for Grok Bot.
        if let r = extras.first(where: { $0.id == "cursor-grok-bot" })?.window { card.meters = [meter(period(r, fallback: "独立额度"), r)] }
    case "workbuddy":
        if let r = usage.primary, r.isSyntheticPlaceholder != true {
            let text = r.resetDescription ?? ""
            let amount = text.range(of: #"^[\d,.]+(?=\s*/.*credits left)"#, options: .regularExpression).map { String(text[$0]) + " 积分" }
            let total = text.range(of: #"(?<=/ )([\d,.]+)(?= credits left)"#, options: .regularExpression).map { String(text[$0]) + " 积分" }
            card.totalCredits = total
            card.meters = [meter("可用积分", r, amount: amount)]
        }
    default:
        if let r = usage.primary, r.isSyntheticPlaceholder != true { card.meters.append(meter(period(r, fallback: "当前额度"), r)) }
        if let r = usage.secondary, r.isSyntheticPlaceholder != true { card.meters.append(meter(period(r, fallback: "第二额度"), r)) }
    }
    let predictions = result.first?.predictions ?? [:]
    for index in card.meters.indices {
        let key: String
        if id == "antigravity", !extras.isEmpty {
            let labels = ["Gemini · 5 小时": "antigravity-quota-summary-gemini-5h", "Gemini · 每周": "antigravity-quota-summary-gemini-weekly", "Claude/GPT · 5 小时": "antigravity-quota-summary-3p-5h", "Claude/GPT · 每周": "antigravity-quota-summary-3p-weekly"]
            key = labels[card.meters[index].label] ?? (index == 0 ? "primary" : "secondary")
        } else { key = (index == 0 && usage.primary != nil && usage.primary?.isSyntheticPlaceholder != true) ? "primary" : "secondary" }
        card.meters[index].forecast = predictions[key]
    }
    if card.meters.isEmpty { throw NSError(domain: "Quota", code: 2) }
    return card
}

struct FetchResult: Sendable {
    let data: Data?
    let error: String?
    var needsConnection: Bool = false
    var connectionIssue: ConnectionIssueKind? = nil
}
func fetchProvider(_ provider: String, connect: Bool = false) -> FetchResult {
    BridgeWorker.request(provider: provider, connect: connect)
}
