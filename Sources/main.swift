import AppKit
import SwiftUI
import Network

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
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = QuotaStore()
    var status: NSStatusItem!
    var popover: NSPopover!
    var window: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let controller = NSHostingController(rootView: Dashboard(store: store))
        popover = NSPopover()
        popover.contentViewController = controller
        popover.contentSize = NSSize(width: 960, height: 520)
        popover.behavior = .transient
        let renderingDemo = CommandLine.arguments.contains("--demo") && CommandLine.arguments.contains("--snapshot")
        if !renderingDemo {
            createStatusItem()
            // CodexBar recreates detached items after AppKit has settled on macOS 26.
            for delay in [3.0, 8.0] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let self else { return }
                    if !self.hasMenuBarAnchor {
                        NSStatusBar.system.removeStatusItem(self.status)
                        UserDefaults.standard.removeObject(forKey: "NSStatusItem Preferred Position huixin-token-manager")
                        self.createStatusItem()
                    }
                    self.traceStatusItem()
                }
            }

        }
        if CommandLine.arguments.contains("--demo") {
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
        } else {
            let connectOnStart = CommandLine.arguments.contains("--connect-browsers")
            store.start(refreshImmediately: !connectOnStart)
            if connectOnStart { store.connect("workbuddy") }
        }
        if CommandLine.arguments.contains("--show") { showWindow() }
        else if CommandLine.arguments.contains("--menu-check") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.showMenu() }
        }
        if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), CommandLine.arguments.indices.contains(i + 1) {
            let path = CommandLine.arguments[i + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + (CommandLine.arguments.contains("--demo") ? 2 : 48)) { [self] in
                let host = NSHostingView(rootView: Dashboard(store: store))
                host.frame = NSRect(x: 0, y: 0, width: 960, height: 520)
                host.layoutSubtreeIfNeeded()
                if let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                    host.cacheDisplay(in: host.bounds, to: bitmap)
                    try? bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
                    if renderingDemo { NSApp.terminate(nil) }
                }
            }
        }
    }
    private var hasMenuBarAnchor: Bool {
        guard let frame = status?.button?.window?.frame, let screen = status?.button?.window?.screen?.frame else { return false }
        return frame.width > 0 && frame.intersects(screen) && frame.minY >= screen.maxY - 60
    }
    private func createStatusItem() {
        let defaults = UserDefaults.standard
        let key = "NSStatusItem Preferred Position huixin-token-manager"
        if defaults.object(forKey: key) != nil {
            let position = defaults.double(forKey: key)
            if !position.isFinite || position <= 0 || position > Double(NSScreen.screens.map { $0.frame.width }.max() ?? 2000) + 512 {
                defaults.removeObject(forKey: key)
            }
        }
        status = NSStatusBar.system.statusItem(withLength: 0)
        status.autosaveName = "huixin-token-manager"
        status.length = NSStatusItem.variableLength
        status.isVisible = true
        if let button = status.button {
            button.title = "token"
            button.imagePosition = .imageLeading
            button.image = BrandMark.image(size: 18, template: true)
            button.toolTip = "汇芯 token 管家"
            button.setAccessibilityLabel("汇芯 token 管家")
            button.target = self; button.action = #selector(toggle)
        }
        traceStatusItem()
    }
    private func traceStatusItem() {
        guard CommandLine.arguments.contains("--diagnostics") else { return }
        print("Menu anchorValid=\(hasMenuBarAnchor) frame=\(status?.button?.window?.frame ?? .zero)")
        fflush(stdout)
    }
    func applicationWillTerminate(_ notification: Notification) { BridgeWorker.shutdownAll() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMenu()
        return false
    }
    func showMenu() {
        guard hasMenuBarAnchor, let button = status.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
        popover.contentViewController?.view.window?.makeKey()
        if CommandLine.arguments.contains("--menu-check") {
            let rect = button.window?.frame ?? .zero
            let screen = button.window?.screen?.frame ?? .zero
            print("Menu visible=\(status.isVisible) popover=\(popover.isShown) anchor=\(rect) screen=\(screen)")
            fflush(stdout)
        }
    }
    @objc func toggle() {
        guard status.button != nil else { return }
        if popover.isShown { popover.performClose(nil) }
        else { showMenu(); if !CommandLine.arguments.contains("--demo") { store.refresh() } }
    }
    func showWindow() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 520), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        w.title = "汇芯 token 管家"
        w.contentView = NSHostingView(rootView: Dashboard(store: store))
        w.isReleasedWhenClosed = false
        w.center(); w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = w
    }
}
if CommandLine.arguments.contains("--engine-check") {
    let url = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/HuixinQuotaBridge")
    let process = Process()
    process.executableURL = url
    process.arguments = ["--version"]
    try process.run(); process.waitUntilExit()
    exit(process.terminationStatus)
}
if CommandLine.arguments.contains("--self-test") {
    let dir = CommandLine.arguments.last!
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
}
let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.run()
