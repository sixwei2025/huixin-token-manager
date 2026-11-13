import AppKit
import SwiftUI

@MainActor final class QuotaStore: ObservableObject {
    @Published var cards = providers
    @Published var refreshing = false
    @Published var connecting: Set<String> = []
    @Published var loading: Set<String> = []
    private var timer: Timer?
    private var cacheURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("汇芯 Token 管家/snapshot.json")
    }
    init() {
        if let data = try? Data(contentsOf: cacheURL), let stored = try? JSONDecoder().decode([QuotaCard].self, from: data) {
            cards = providers.map { p in
                var c = stored.first { $0.id == p.id } ?? p
                if c.updated != nil { c.issue = "正在核对" }
                return c
            }
        }
    }
    func connect(_ id: String) {
        guard !connecting.contains(id) else { return }
        connecting.insert(id)
        Task {
            let result = await Task.detached { connectBrowser(id) }.value
            connecting.remove(id)
            if let index = cards.firstIndex(where: { $0.id == id }) {
                if let data = result.data, let card = try? decodeCard(id: id, data: data) {
                    cards[index] = card
                } else { cards[index].issue = result.error ?? "连接未完成，请检查网页登录和系统授权" }
            }
            if connecting.isEmpty { refresh() }
        }
    }
    func start(refreshImmediately: Bool = true) {
        if refreshImmediately { refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }
    func refresh() {
        guard !refreshing else { return }
        refreshing = true
        loading = Set(providers.map(\.id))
        for provider in providers {
            Task {
                let result = await Task.detached { fetchProvider(provider.id) }.value
                guard let index = cards.firstIndex(where: { $0.id == provider.id }) else { return }
                if let data = result.data, let card = try? decodeCard(id: provider.id, data: data) {
                    cards[index] = card
                } else {
                    cards[index].issue = result.error ?? "未读取到独立额度，请在原工具中检查"
                }
                loading.remove(provider.id)
                if loading.isEmpty {
                    refreshing = false
                    try? FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    if let data = try? JSONEncoder().encode(cards) { try? data.write(to: cacheURL, options: .atomic) }
                }
            }
        }
    }
}
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
struct MeterView: View {
    let meter: Meter
    var compact = false
    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text(compact ? meter.label.components(separatedBy: " · ").last! : meter.label).lineLimit(1).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Text(meter.amount ?? meter.remaining.map { String(format: "%.0f%%", $0) } ?? "—")
                    .font(.system(size: 20, weight: .semibold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(quotaColor(meter.remaining))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.06))
                    Capsule().fill(quotaColor(meter.remaining)).frame(width: geo.size.width * (meter.remaining ?? 0) / 100)
                }
            }.frame(height: 5)
            if meter.reset != nil {
                HStack { Text(resetText(meter.reset)).font(.system(size: 10)).foregroundStyle(.tertiary); Spacer() }
            }
        }
    }
}
struct CardView: View {
    let card: QuotaCard
    let loading: Bool
    var icon: String {
        switch card.id { case "codex": return "chevron.left.forwardslash.chevron.right"; case "antigravity": return "sparkles"; case "cursor": return "bolt.fill"; default: return "square.stack.3d.up.fill" }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(accent)
                    .frame(width: 34, height: 34).background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.name).font(.system(size: 17, weight: .semibold))
                    Text(card.subtitle).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                if loading { ProgressView().controlSize(.small) }
                else if card.issue != nil { Image(systemName: "exclamationmark.circle").foregroundStyle(.orange).help(card.issue ?? "") }
            }
            if card.meters.isEmpty {
                Spacer()
                Text(loading ? "正在读取额度…" : card.issue ?? "等待连接").font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Spacer()
            } else if card.id == "antigravity" && card.meters.count == 4 {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) { Text("Gemini").font(.system(size: 11, weight: .semibold)); MeterView(meter: card.meters[0], compact: true); MeterView(meter: card.meters[1], compact: true) }
                    VStack(alignment: .leading, spacing: 5) { Text("Claude / GPT").font(.system(size: 11, weight: .semibold)); MeterView(meter: card.meters[2], compact: true); MeterView(meter: card.meters[3], compact: true) }
                }
            } else {
                if card.id == "workbuddy" {
                    HStack {
                        Text("总积分").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                        Spacer()
                        Text(card.totalCredits ?? "—").font(.system(size: 20, weight: .semibold, design: .rounded)).monospacedDigit()
                    }
                }
                ForEach(card.meters) { MeterView(meter: $0) }
                Spacer(minLength: 0)
            }
            if let issue = card.issue, !card.meters.isEmpty {
                Text("上次数据 · \(issue)").font(.system(size: 10)).foregroundStyle(.orange).lineLimit(1).help(issue)
            } else if let updated = card.updated {
                HStack(spacing: 4) {
                    Circle().fill(Color.green).frame(width: 4, height: 4)
                    Text("更新于 " + updated.formatted(date: .omitted, time: .shortened)).font(.system(size: 10)).foregroundStyle(.tertiary)
                    Spacer()
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.055)))
    }
}
struct Dashboard: View {
    @ObservedObject var store: QuotaStore
    @State private var details = false
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Text("汇芯").font(.system(size: 15, weight: .bold)).foregroundStyle(.white).padding(9).background(accent, in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Token 管家").font(.system(size: 22, weight: .bold))
                    Text("还剩多少，一眼就知道").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Text("显示剩余额度").font(.system(size: 11)).foregroundStyle(.secondary)
                Button { store.refresh() } label: { Label(store.refreshing ? "刷新中" : "刷新", systemImage: "arrow.clockwise") }.disabled(store.refreshing || CommandLine.arguments.contains("--demo")).controlSize(.small)
                Menu {
                    Button("连接与来源") { details = true }
                    Button("打开独立窗口") { (NSApp.delegate as? AppDelegate)?.showWindow() }
                    Divider()
                    Button("退出汇芯 Token 管家") { NSApp.terminate(nil) }
                } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 24)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible())], spacing: 14) {
                ForEach(store.cards) { card in CardView(card: card, loading: store.loading.contains(card.id)).frame(height: 224) }
            }
            HStack {
                Text(CommandLine.arguments.contains("--demo") ? "演示数据 · 安装后读取本机账号" : "每分钟自动更新 · 只看可用额度").font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Button("连接与来源") { details = true }.buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }
        .padding(22).frame(width: 820, height: 588)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $details) {
            VStack(alignment: .leading, spacing: 16) {
                Text("连接与来源").font(.title2.bold())
                Text("汇芯 Token 管家 · 袁六伟 / 台州汇芯\n界面为独立开发，已内置 Peter Steinberger 的 CodexBar 读取引擎（MIT），无需另装 CodexBar。\n适用：Apple 芯片 Mac、macOS 14 及以上。暂不支持 Windows 和 Intel Mac。")
                Text("Codex：显示真实周期额度。Antigravity：区分 Gemini 与 Claude/GPT。Grok Bot：只读取 Cursor 提供的 Grok Bot 独立额度。WorkBuddy：显示总积分和可用积分。没有的周期不编造。")
                Text("请先在自己的工具中登录：Codex 使用 Codex CLI 登录；Antigravity 需要安装并登录本机应用；Grok Bot 和 WorkBuddy 需要相应网站登录状态。浏览器和钥匙串权限依系统提示处理。\n读取失败会标记旧数据。本地缓存不含邮箱、密码和原始登录响应。")
                Text("点击“连接浏览器”会尝试读取本人已登录的网页会话，可能弹出 macOS 钥匙串授权；请按系统提示自行确认。不连接也可查看其他工具。")
                ForEach(store.cards) { c in
                    HStack {
                        Text(c.name).bold()
                        Spacer()
                        Text(c.issue ?? (c.updated == nil ? "尚未连接" : "已读取")).foregroundStyle(.secondary).lineLimit(2)
                        if ["cursor", "workbuddy"].contains(c.id) {
                            Button(store.connecting.contains(c.id) ? "等待授权…" : "连接浏览器") { store.connect(c.id) }
                                .disabled(store.connecting.contains(c.id) || CommandLine.arguments.contains("--demo"))
                        }
                    }
                }
                HStack { Link("CodexBar 开源项目", destination: URL(string: "https://github.com/steipete/CodexBar")!); Spacer(); Button("完成") { details = false }.keyboardShortcut(.defaultAction) }
            }.font(.system(size: 12)).padding(24).frame(width: 540)
        }
    }
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
        popover.contentSize = NSSize(width: 820, height: 588)
        popover.behavior = .transient
        let positionKey = "NSStatusItem Preferred Position HuixinTokenManager"
        if CommandLine.arguments.contains("--align-with-skills"), let position = positionBesideSkills() {
            UserDefaults.standard.set(position, forKey: positionKey)
            print("Menu grouping position: \(position)")
            fflush(stdout)
        }
        if UserDefaults.standard.object(forKey: positionKey) == nil {
            UserDefaults.standard.set(0, forKey: positionKey)
        }
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.autosaveName = "HuixinTokenManager"
        status.isVisible = true
        if let button = status.button {
            button.image = NSImage(systemSymbolName: "chart.bar.xaxis", accessibilityDescription: "汇芯 Token 管家")
            button.image?.isTemplate = true
            button.image?.size = NSSize(width: 18, height: 18)
            button.toolTip = "汇芯 Token 管家"
            button.setAccessibilityLabel("汇芯 Token 管家")
            button.target = self; button.action = #selector(toggle)
        }
        if CommandLine.arguments.contains("--demo") {
            store.cards = providers.map { provider in
                var card = provider
                let future = Date().addingTimeInterval(3 * 3600)
                func sample(_ label: String, _ remaining: Double) -> Meter { Meter(label: label, remaining: remaining, reset: future, amount: nil) }
                switch card.id {
                case "codex": card.meters = [sample("5 小时", 85), sample("每周", 62)]
                case "antigravity": card.meters = [sample("Gemini · 5 小时", 78), sample("Gemini · 每周", 71), sample("Claude/GPT · 5 小时", 73), sample("Claude/GPT · 每周", 65)]
                case "cursor": card.meters = [sample("每周", 45)]
                default:
                    card.totalCredits = "5,000 积分"
                    card.meters = [Meter(label: "可用积分", remaining: 62.4, reset: future, amount: "3,120 积分")]
                }
                return card
            }
        } else {
            let connectOnStart = CommandLine.arguments.contains("--connect-browsers")
            store.start(refreshImmediately: !connectOnStart)
            if connectOnStart { store.connect("workbuddy"); store.connect("cursor") }
        }
        if CommandLine.arguments.contains("--show") { showWindow() }
        else if CommandLine.arguments.contains("--menu-check") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.showMenu() }
        }
        if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), CommandLine.arguments.indices.contains(i + 1) {
            let path = CommandLine.arguments[i + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + (CommandLine.arguments.contains("--demo") ? 2 : 48)) { [self] in
                let host = NSHostingView(rootView: Dashboard(store: store))
                host.frame = NSRect(x: 0, y: 0, width: 820, height: 588)
                host.layoutSubtreeIfNeeded()
                if let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                    host.cacheDisplay(in: host.bounds, to: bitmap)
                    try? bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
                }
            }
        }
    }
    func positionBesideSkills() -> Double? {
        guard let buddy = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "cn.huixin.skillsmanager" }),
              let windows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return nil }
        for window in windows {
            guard (window[kCGWindowOwnerPID as String] as? Int) == Int(buddy.processIdentifier),
                  let layer = window[kCGWindowLayer as String] as? Int, layer > 0,
                  let bounds = window[kCGWindowBounds as String] as? [String: Double],
                  let x = bounds["X"], let width = bounds["Width"], let height = bounds["Height"],
                  height >= 18, height <= 40, width >= 18, width <= 80,
                  let screen = NSScreen.screens.first(where: { x >= $0.frame.minX && x < $0.frame.maxX }) else { continue }
            // Preferred positions are distances from the screen's right edge. Insert immediately
            // to the left of the existing Skills Manager item, without changing the other app.
            return max(0, screen.frame.maxX - x + 1)
        }
        return nil
    }
    func applicationWillTerminate(_ notification: Notification) { BridgeWorker.shared.shutdown() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMenu()
        return false
    }
    func showMenu() {
        guard let button = status.button else { return }
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
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 588), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        w.title = "汇芯 Token 管家"
        w.contentView = NSHostingView(rootView: Dashboard(store: store))
        w.isReleasedWhenClosed = false
        w.center(); w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = w
    }
}
if CommandLine.arguments.contains("--engine-check") {
    let url = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/CodexBarCLI")
    let process = Process()
    process.executableURL = url
    process.arguments = ["--version"]
    try process.run(); process.waitUntilExit()
    exit(process.terminationStatus)
}
if CommandLine.arguments.contains("--self-test") {
    let dir = CommandLine.arguments.last!
    for name in ["codex", "antigravity", "cursor", "workbuddy"] {
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
    print("通过：四项真实数据结构、剩余百分比、模型双周期、独立 Grok 额度、积分、缺失处理、缓存无账号字段")
    exit(0)
}
let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.run()
