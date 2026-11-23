import Foundation
import CodexBarCore

struct Request: Decodable { let provider: String; let connect: Bool }
struct Prediction: Encodable {
    let etaSeconds: Double?
    let willLastToReset: Bool
    let basis = "cycle"
}
struct Response: Encodable {
    let provider: String
    let usage: UsageSnapshot?
    let error: String?
    var predictions: [String: Prediction]? = nil
}
@main struct Bridge {
    static func predictions(_ usage: UsageSnapshot) -> [String: Prediction] {
        var windows: [(String, RateWindow?)] = [("primary", usage.primary), ("secondary", usage.secondary)]
        windows += (usage.extraRateWindows ?? []).map { ($0.id, Optional($0.window)) }
        var result: [String: Prediction] = [:]
        for (key, optional) in windows {
            guard let window = optional, let minutes = window.windowMinutes, minutes > 0, !window.isSyntheticPlaceholder,
                  let pace = UsagePace.weekly(window: window, defaultWindowMinutes: minutes) else { continue }
            if pace.etaSeconds != nil || pace.willLastToReset {
                result[key] = Prediction(etaSeconds: pace.etaSeconds, willLastToReset: pace.willLastToReset)
            }
        }
        return result
    }
    static func fetch(_ request: Request) async -> Response {
        guard let provider = UsageProvider(rawValue: request.provider), ["codex", "antigravity", "workbuddy"].contains(request.provider) else {
            return Response(provider: request.provider, usage: nil, error: "Unsupported provider")
        }
        let config = try? CodexBarConfigStore().load()
        let providerConfig = config?.providerConfig(for: provider.instanceID)
        let env = ProviderConfigEnvironment.applyProviderConfigOverrides(base: ProcessInfo.processInfo.environment, provider: provider, config: providerConfig)
        let descriptor = ProviderDescriptorRegistry.descriptor(for: provider)
        let contribution = descriptor.settingsSection.credentialContribution(context: ProviderCredentialSettingsContext(config: providerConfig, account: nil))
        let settings = contribution.map { ProviderSettingsSnapshot(contributions: [$0]) }
        let context = ProviderFetchContext(runtime: request.provider == "workbuddy" ? .app : .cli, sourceMode: request.provider == "workbuddy" ? .web : .auto, includeCredits: false,
            includeOptionalUsage: true, webTimeout: request.provider == "workbuddy" ? 25 : 12, webDebugDumpHTML: false, verbose: false,
            env: env, settings: settings, fetcher: UsageFetcher(), claudeFetcher: ClaudeUsageFetcher(browserDetection: BrowserDetection()),
            browserDetection: BrowserDetection(), persistsCLISessions: true)
        func runOnce() async -> ProviderFetchOutcome {
            if request.connect {
                return await BrowserCookieAccessGate.withExplicitRetry(bypassingCooldown: true) {
                    await ProviderInteractionContext.$current.withValue(.userInitiated) {
                        await descriptor.fetchOutcome(context: context)
                    }
                }
            }
            return await ProviderInteractionContext.$current.withValue(.background) {
                await descriptor.fetchOutcome(context: context)
            }
        }
        var outcome = await runOnce()
        // Right after wake/unlock, Keychain or network may be momentarily unavailable; one short silent retry
        // prevents a transient wake race from marking WorkBuddy offline.
        if !request.connect, request.provider == "workbuddy", case .failure(let firstError) = outcome.result {
            let lower = firstError.localizedDescription.lowercased()
            let definitiveAuth = ["session expired", "no workbuddy session cookies", "cookies are disabled", "http 401", "keychain permission"].contains { lower.contains($0) }
            if !definitiveAuth {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                outcome = await runOnce()
            }
        }
        switch outcome.result {
        case .success(let value): return Response(provider: request.provider, usage: value.usage, error: nil, predictions: predictions(value.usage))
        case .failure(let error): return Response(provider: request.provider, usage: nil, error: error.localizedDescription)
        }
    }
    static func main() async {
        if CommandLine.arguments.contains("--version") { print("CodexBarCore 0.85.0 · Huixin persistent provider bridge"); return }
        if CommandLine.arguments.contains("--resource-check") {
            let directory = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL.deletingLastPathComponent()
            guard let bundle = CodexBarCoreResources.bundle,
                  bundle.bundleURL.standardizedFileURL.path.lowercased().hasPrefix(directory.path.lowercased() + "/"),
                  bundle.url(forResource: "workbuddy", withExtension: "js") != nil else {
                print("Resource check failed. Resolved:", CodexBarCoreResources.bundle?.bundleURL.path ?? "none", "Expected parent:", directory.path); exit(1)
            }
            print("PASS: self-contained packaged core and WorkBuddy resources")
            return
        }
        if CommandLine.arguments.contains("--forecast-test") {
            let now = Date()
            let window = RateWindow(usedPercent: 80, windowMinutes: 300, resetsAt: now.addingTimeInterval(9000), resetDescription: nil)
            let pace = UsagePace.weekly(window: window, now: now)!
            precondition(abs((pace.etaSeconds ?? 0) - 2250) < 0.01 && !pace.willLastToReset)
            let safe = RateWindow(usedPercent: 20, windowMinutes: 300, resetsAt: now.addingTimeInterval(9000), resetDescription: nil)
            precondition(UsagePace.weekly(window: safe, now: now)?.willLastToReset == true)
            let expired = RateWindow(usedPercent: 20, windowMinutes: 300, resetsAt: now.addingTimeInterval(-1), resetDescription: nil)
            precondition(UsagePace.weekly(window: expired, now: now) == nil)
            print("PASS: upstream UsagePace cycle ETA, safe-to-reset, expired-window rejection")
            return
        }
        while let line = readLine() {
            guard let data = line.data(using: .utf8), let request = try? JSONDecoder().decode(Request.self, from: data) else { continue }
            let result = await fetch(request)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode([result]) {
                FileHandle.standardOutput.write(data)
                FileHandle.standardOutput.write(Data([10]))
            }
        }
        await ProviderCLISessionLifecycle.shutdownPersistentSessions()
    }
}
