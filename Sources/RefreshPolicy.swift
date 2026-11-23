import Foundation

enum RefreshPolicy {
    static let recoveryInterval: TimeInterval = 180
    static let forcedRecoveryMinGap: TimeInterval = 8

    static func delay(failures: Int, lowPower: Bool) -> TimeInterval {
        let base: TimeInterval = lowPower ? 60 : 30
        return min(300, base * pow(2, Double(max(0, min(failures - 1, 4)))))
    }
    static func isDue(now: Date, lastAttempt: Date?, failures: Int, blocked: Bool,
                      inFlight: Bool, force: Bool, lowPower: Bool) -> Bool {
        guard !blocked && !inFlight else { return false }
        guard !force, let lastAttempt else { return true }
        return now.timeIntervalSince(lastAttempt) >= delay(failures: failures, lowPower: lowPower)
    }
    /// Silent no-UI recovery check for auth-blocked providers so transient wake/keychain locks
    /// or renewed browser logins recover automatically without requiring manual reconnect clicks.
    static func isRecoveryDue(now: Date, lastAttempt: Date?, blocked: Bool, inFlight: Bool, force: Bool) -> Bool {
        guard blocked && !inFlight else { return false }
        guard let lastAttempt else { return true }
        let elapsed = now.timeIntervalSince(lastAttempt)
        return force ? elapsed >= forcedRecoveryMinGap : elapsed >= recoveryInterval
    }
}
