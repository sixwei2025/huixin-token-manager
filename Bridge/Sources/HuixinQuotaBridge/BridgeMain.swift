import Foundation
import CodexBarCore

struct Request: Decodable { let provider: String; let connect: Bool }
struct Response: Encodable { let provider: String; let usage: UsageSnapshot?; let error: String? }
@main struct Bridge {
    static func fetch(_ request: Request) async -> Response {
        guard let provider = UsageProvider(rawValue: request.provider), ["cursor", "workbuddy"].contains(request.provider) else {
            return Response(provider: request.provider, usage: nil, error: "Unsupported provider")
        }
        let config = try? CodexBarConfigStore().load()
        let providerConfig = config?.providerConfig(for: provider.instanceID)
        let env = ProviderConfigEnvironment.applyProviderConfigOverrides(base: ProcessInfo.processInfo.environment, provider: provider, config: providerConfig)
        let descriptor = ProviderDescriptorRegistry.descriptor(for: provider)
        let contribution = descriptor.settingsSection.credentialContribution(context: ProviderCredentialSettingsContext(config: providerConfig, account: nil))
        let settings = contribution.map { ProviderSettingsSnapshot(contributions: [$0]) }
        let context = ProviderFetchContext(runtime: .app, sourceMode: .web, includeCredits: false,
            includeOptionalUsage: true, webTimeout: 40, webDebugDumpHTML: false, verbose: false,
            env: env, settings: settings, fetcher: UsageFetcher(), claudeFetcher: ClaudeUsageFetcher(browserDetection: BrowserDetection()),
            browserDetection: BrowserDetection(), persistsCLISessions: true)
        let outcome: ProviderFetchOutcome
        if request.connect {
            outcome = await BrowserCookieAccessGate.withExplicitRetry(bypassingCooldown: true) {
                await ProviderInteractionContext.$current.withValue(.userInitiated) {
                    await descriptor.fetchOutcome(context: context)
                }
            }
        } else {
            outcome = await ProviderInteractionContext.$current.withValue(.background) {
                await descriptor.fetchOutcome(context: context)
            }
        }
        switch outcome.result {
        case .success(let value): return Response(provider: request.provider, usage: value.usage, error: nil)
        case .failure(let error): return Response(provider: request.provider, usage: nil, error: error.localizedDescription)
        }
    }
    static func main() async {
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
