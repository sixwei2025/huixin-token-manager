import Foundation

@main struct PolicyForecastTests {
    static func main() throws {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        precondition(!RefreshPolicy.isDue(now: now, lastAttempt: nil, failures: 0, blocked: true, inFlight: false, force: true, lowPower: false))
        precondition(!RefreshPolicy.isDue(now: now, lastAttempt: nil, failures: 0, blocked: false, inFlight: true, force: true, lowPower: false))
        precondition(RefreshPolicy.isDue(now: now, lastAttempt: now, failures: 0, blocked: false, inFlight: false, force: true, lowPower: false))
        precondition(!RefreshPolicy.isDue(now: now, lastAttempt: now.addingTimeInterval(-20), failures: 0, blocked: false, inFlight: false, force: false, lowPower: false))
        precondition(RefreshPolicy.delay(failures: 5, lowPower: false) == 300)
        precondition(RefreshPolicy.delay(failures: 0, lowPower: true) == 60)
        precondition(!RefreshPolicy.isRecoveryDue(now: now, lastAttempt: now.addingTimeInterval(-60), blocked: true, inFlight: false, force: false))
        precondition(RefreshPolicy.isRecoveryDue(now: now, lastAttempt: now.addingTimeInterval(-181), blocked: true, inFlight: false, force: false))
        precondition(RefreshPolicy.isRecoveryDue(now: now, lastAttempt: now.addingTimeInterval(-10), blocked: true, inFlight: false, force: true))
        precondition(!RefreshPolicy.isRecoveryDue(now: now, lastAttempt: now.addingTimeInterval(-3), blocked: true, inFlight: false, force: true))
        precondition(!RefreshPolicy.isRecoveryDue(now: now, lastAttempt: nil, blocked: false, inFlight: false, force: true))
        let tlsSessionErr = BridgeWorker.classifyError(provider: "workbuddy", error: "URLSession task failed: TLS session interrupted")
        precondition(!tlsSessionErr.needsConnection && tlsSessionErr.kind == nil)
        let keychainErr = BridgeWorker.classifyError(provider: "workbuddy", error: "Chrome cookie access needs Keychain permission — use Refresh...")
        precondition(keychainErr.needsConnection && keychainErr.kind == .keychainPermission)
        let expiredErr = BridgeWorker.classifyError(provider: "workbuddy", error: "WorkBuddy session expired. Sign in at www.workbuddy.cn")
        precondition(expiredErr.needsConnection && expiredErr.kind == .sessionExpired)
        let samples = [TrendPoint(date: now.addingTimeInterval(-1200), remaining: 90, reset: nil, capacity: nil),
                       TrendPoint(date: now.addingTimeInterval(-600), remaining: 85, reset: nil, capacity: nil),
                       TrendPoint(date: now, remaining: 80, reset: nil, capacity: nil)]
        let prediction = UsageTrendStore.forecast(samples, current: 80, reset: nil, now: now)
        precondition(prediction?.etaSeconds == 9600)
        let reset = UsageTrendStore.forecast(samples, current: 80, reset: now.addingTimeInterval(1800), now: now)
        precondition(reset?.willLastToReset == true && reset?.etaSeconds == nil)
        precondition(UsageTrendStore.forecast(Array(samples.prefix(2)), current: 80, reset: nil, now: now) == nil)
        precondition(UsageTrendStore.forecast(samples, current: 80, reset: now.addingTimeInterval(-1), now: now) == nil)
        precondition(UsageTrendStore.forecast(samples, current: 80, reset: nil, now: now.addingTimeInterval(180)) == nil)
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: tmp) }
        let store = UsageTrendStore(file: tmp)
        var card = QuotaCard(id: "test", name: "test", subtitle: "test")
        card.meters = [Meter(label: "quota", remaining: 90, reset: nil, amount: nil)]
        _ = store.apply(to: card, now: now.addingTimeInterval(-1200))
        card.meters = [Meter(label: "quota", remaining: 85, reset: nil, amount: nil)]
        _ = store.apply(to: card, now: now.addingTimeInterval(-600))
        card.meters = [Meter(label: "quota", remaining: 80, reset: nil, amount: nil)]
        precondition(store.apply(to: card, now: now).meters[0].forecast?.etaSeconds == 9600)
        card.meters = [Meter(label: "quota", remaining: 100, reset: nil, amount: nil)]
        precondition(store.apply(to: card, now: now.addingTimeInterval(60)).meters[0].forecast == nil)
        print("PASS: auth stops background retry; per-provider dedup; manual refresh; capped backoff; low power; forecast sample threshold; reset boundary; stale history; top-up reset")
    }
}
