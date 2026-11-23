import AppKit
import SwiftUI
import Network

@MainActor final class QuotaStore: ObservableObject {
    @Published var cards = providers
    @Published var connecting: Set<String> = []
    @Published var loading: Set<String> = []
    @Published var blocked: Set<String> = []
    var refreshing: Bool { !loading.isEmpty }
    private let trends = UsageTrendStore()
    private var attempts: [String: Date] = [:]
    private var failures: [String: Int] = [:]
    private var refreshTask: Task<Void, Never>?
    private var wakeObserver: NSObjectProtocol?
    private let networkMonitor = NWPathMonitor()
    private var networkWasAvailable = false
    private var cacheURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("汇芯 Token 管家/snapshot.json")
    }
    init() {
        if let data = try? Data(contentsOf: cacheURL), let stored = try? JSONDecoder().decode([QuotaCard].self, from: data) {
            cards = providers.map { p in
                var c = stored.first { $0.id == p.id } ?? p
                c.name = p.name; c.subtitle = p.subtitle
                return c
            }
        }
    }
    func start(refreshImmediately: Bool = true) {
        refreshTask?.cancel()
        if refreshImmediately { refresh() }
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: 2_000_000_000) } catch { return }
                guard !Task.isCancelled else { return }
                self?.refresh()
            }
        }
        if wakeObserver == nil {
            wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    self?.refresh(force: true)
                    // Second gentle pass after Wi-Fi/Keychain fully settle post-wake.
                    try? await Task.sleep(nanoseconds: 8_000_000_000)
                    self?.retryUnhealthySilently()
                }
            }
            networkMonitor.pathUpdateHandler = { [weak self] path in
                let available = path.status == .satisfied
                Task { @MainActor in
                    guard let self else { return }
                    let restored = available && !self.networkWasAvailable
                    self.networkWasAvailable = available
                    if restored {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        self.refresh(force: true)
                    }
                }
            }
            networkMonitor.start(queue: DispatchQueue(label: "cn.huixin.quota.network"))
        }
    }
    func refresh(force: Bool = false) {
        guard !CommandLine.arguments.contains("--demo") else { return }
        let now = Date()
        for provider in providers {
            let id = provider.id
            let isBlocked = blocked.contains(id)
            if RefreshPolicy.isDue(now: now, lastAttempt: attempts[id], failures: failures[id, default: 0],
                blocked: isBlocked, inFlight: loading.contains(id), force: force,
                lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled) {
                launch(id, connect: false)
            } else if RefreshPolicy.isRecoveryDue(now: now, lastAttempt: attempts[id],
                blocked: isBlocked, inFlight: loading.contains(id), force: force) {
                // Silent no-UI probe: recovers automatically once Keychain unlocks or Chrome renews the cookie.
                launch(id, connect: false)
            }
        }
    }
    func onPopoverOpen() {
        guard !CommandLine.arguments.contains("--demo") else { return }
        let now = Date()
        for provider in providers {
            let id = provider.id
            guard !loading.contains(id) else { continue }
            let hasIssue = cards.first(where: { $0.id == id })?.issue != nil
            if (blocked.contains(id) || hasIssue),
               let last = attempts[id], now.timeIntervalSince(last) >= 10 {
                launch(id, connect: false)
            }
        }
    }
    private func retryUnhealthySilently() {
        guard !CommandLine.arguments.contains("--demo") else { return }
        let now = Date()
        for provider in providers {
            let id = provider.id
            guard !loading.contains(id) else { continue }
            let hasIssue = cards.first(where: { $0.id == id })?.issue != nil
            if (blocked.contains(id) || hasIssue),
               attempts[id].map({ now.timeIntervalSince($0) >= 6 }) ?? true {
                launch(id, connect: false)
            }
        }
    }
    func manualRefresh() {
        guard !CommandLine.arguments.contains("--demo") else { return }
        for provider in providers where !loading.contains(provider.id) {
            // Manual refresh retries native providers and quietly re-checks cached WorkBuddy sessions without prompting.
            let shouldConnect = blocked.contains(provider.id) && provider.id != "workbuddy"
            launch(provider.id, connect: shouldConnect)
        }
    }
    func connect(_ id: String) {
        guard !loading.contains(id) else { return }
        blocked.remove(id)
        launch(id, connect: true)
    }
    private func launch(_ id: String, connect: Bool) {
        loading.insert(id)
        if connect { connecting.insert(id) }
        attempts[id] = Date()
        let started = Date()
        Task {
            let result = await Task.detached(priority: .utility) { fetchProvider(id, connect: connect) }.value
            defer { loading.remove(id); connecting.remove(id) }
            guard let index = cards.firstIndex(where: { $0.id == id }) else { return }
            var success = false
            if let data = result.data, var card = try? decodeCard(id: id, data: data) {
                card.issue = nil
                card.connectionIssue = nil
                cards[index] = trends.apply(to: card)
                failures[id] = 0
                blocked.remove(id)
                success = true
            } else {
                failures[id, default: 0] += 1
                cards[index].issue = result.error ?? "服务暂时没有返回额度，稍后自动重试"
                cards[index].connectionIssue = result.connectionIssue
                if result.needsConnection { blocked.insert(id) }
            }
            persist()
            if CommandLine.arguments.contains("--diagnostics") {
                print("Refresh provider=\(id) success=\(success) duration=\(String(format: "%.2f", Date().timeIntervalSince(started)))s blocked=\(blocked.contains(id))")
                fflush(stdout)
            }
        }
    }
    private func persist() {
        try? FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(cards) { try? data.write(to: cacheURL, options: .atomic) }
    }
}
