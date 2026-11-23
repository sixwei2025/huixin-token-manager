import AppKit
import SwiftUI

let accent = Color(red: 0.77, green: 0.08, blue: 0.19)
func quotaColor(_ remaining: Double?) -> Color {
    guard let remaining else { return .secondary }
    return remaining <= 10 ? accent : remaining <= 25 ? .orange : Color(red: 0.08, green: 0.51, blue: 0.43)
}
func resetText(_ date: Date?) -> String {
    guard let date else { return "" }
    let seconds = date.timeIntervalSinceNow
    if seconds <= 0 { return "已到恢复时间 · 等待刷新" }
    if seconds < 3600 { return "\(max(1, Int(ceil(seconds / 60)))) 分钟后恢复" }
    if seconds < 86400 { return "\(Int(seconds / 3600)) 小时 \(Int(seconds.truncatingRemainder(dividingBy: 3600) / 60)) 分钟后恢复" }
    return "\(Int(seconds / 86400)) 天 \(Int(seconds.truncatingRemainder(dividingBy: 86400) / 3600)) 小时后恢复"
}

@MainActor final class AppWindowHelper {
    static let shared = AppWindowHelper()
    var window: NSWindow?

    static func populateDemo(store: QuotaStore) {
        store.cards = providers.map { provider in
            var card = provider
            let future = Date().addingTimeInterval(3 * 3600)
            func sample(_ label: String, _ remaining: Double) -> Meter {
                var meter = Meter(label: label, remaining: remaining, reset: future, amount: nil)
                meter.forecast = QuotaForecast(etaSeconds: remaining < 65 ? 7200 : nil, willLastToReset: remaining >= 65)
                return meter
            }
            switch card.id {
            case "codex": card.meters = [sample("5 小时", 85), sample("每周", 62)]
            case "antigravity": card.meters = [sample("Gemini · 5 小时", 78), sample("Gemini · 每周", 71), sample("Claude/GPT · 5 小时", 73), sample("Claude/GPT · 每周", 65)]
            case "cursor": card.meters = [sample("每周", 45)]
            default:
                card.totalCredits = "5,000 积分"
                card.meters = [Meter(label: "可用积分", remaining: 62.4, reset: future, amount: "3,120 积分", forecast: QuotaForecast(etaSeconds: 9000, willLastToReset: false, basis: "recent"))]
            }
            return card
        }
    }

    func showWindow(store: QuotaStore) {
        if let w = window {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 520), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        w.title = "汇芯 token 管家"
        w.contentView = NSHostingView(rootView: Dashboard(store: store))
        w.isReleasedWhenClosed = false
        w.center(); w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = w
    }
}

func runCLIArgsIfNeeded() {
    if CommandLine.arguments.contains("--engine-check") {
        let url = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/HuixinQuotaBridge")
        let process = Process()
        process.executableURL = url
        process.arguments = ["--version"]
        do {
            try process.run(); process.waitUntilExit()
            exit(process.terminationStatus)
        } catch {
            fputs("Engine check failed: \(error)\n", stderr)
            exit(1)
        }
    }
    if CommandLine.arguments.contains("--self-test") {
        let dir = CommandLine.arguments.last!
        do {
            for name in providers.map(\.id) {
                let c = try decodeCard(id: name, data: Data(contentsOf: URL(fileURLWithPath: dir + "/" + name + "-final.json")))
                precondition(!c.meters.isEmpty)
                if name == "codex" { precondition(c.meters.count == 2 && c.meters[0].remaining == 95 && c.meters[1].label == "每周") }
                if name == "antigravity" { precondition(c.meters.count == 4 && c.meters[2].remaining == 0) }
                if name == "cursor" { precondition(c.meters.count == 1 && c.meters[0].remaining == 0) }
                if name == "workbuddy" { precondition(c.meters[0].amount == "3,120 积分" && c.meters[0].label == "可用积分" && c.totalCredits == "5,000 积分") }
            }
            let missing = Data("[{\"usage\":{\"primary\":{\"usedPercent\":5}}}]".utf8)
            precondition((try? decodeCard(id: "cursor", data: missing)) == nil)
            let redacted = try JSONEncoder().encode(decodeCard(id: "codex", data: Data(contentsOf: URL(fileURLWithPath: dir + "/codex-final.json"))))
            precondition(!String(decoding: redacted, as: UTF8.self).contains("accountEmail"))
            print("通过：三项真实数据结构、剩余百分比、模型双周期、积分、已移除来源拒绝读取、缓存无账号字段")
            exit(0)
        } catch {
            fputs("Self test failed: \(error)\n", stderr)
            exit(1)
        }
    }
}
