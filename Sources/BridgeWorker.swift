import Foundation

/// Each provider owns its process and in-memory sessions. A slow browser or network never blocks another provider.
final class BridgeWorker {
    private static let workers: [String: BridgeWorker] = Dictionary(uniqueKeysWithValues:
        ["codex", "antigravity", "workbuddy"].map { ($0, BridgeWorker()) })
    private let requestLock = NSLock()
    private let processLock = NSLock()
    private var process: Process?
    private var input: FileHandle?
    private var output: FileHandle?

    private static let logLock = NSLock()
    private static var logURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("汇芯 Token 管家/bridge.log")
    }
    private static func recordDiagnostic(_ line: String) {
        logLock.lock(); defer { logLock.unlock() }
        let url = logURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let entry = "[\(ISO8601DateFormatter().string(from: Date()))] \(line)\n"
        if let existing = try? Data(contentsOf: url), existing.count > 64 * 1024 {
            let trimmed = existing.suffix(32 * 1024)
            try? (trimmed + Data(entry.utf8)).write(to: url, options: .atomic)
        } else if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(entry.utf8))
        } else {
            try? Data(entry.utf8).write(to: url, options: .atomic)
        }
    }
    static func classifyError(provider: String, error: String) -> (message: String, needsConnection: Bool, kind: ConnectionIssueKind?) {
        let lower = error.lowercased()
        let isKeychainPermission = [
            "keychain permission",
            "chrome cookie access needs keychain",
            "keychain access",
        ].contains { lower.contains($0) }
        let isAuthExpired = [
            "workbuddy session expired",
            "no workbuddy session cookies",
            "cookies are disabled",
            "sign in at www.workbuddy.cn",
            "http 401",
            "status 401",
            "unauthorized",
            "authenticationexpired",
            "missingcredential",
            "please log in",
            "re-authenticate",
        ].contains { lower.contains($0) }
        let isGenericAuth = provider != "workbuddy" && ["login", "log in", "authentication", "unauthorized", "401"].contains { lower.contains($0) }
        if provider == "workbuddy" {
            if isKeychainPermission {
                return ("需在钥匙串弹窗点击「始终允许」以永久授权", true, .keychainPermission)
            }
            if isAuthExpired {
                return ("Chrome 中 WorkBuddy 登录已过期，请刷新官网", true, .sessionExpired)
            }
            return ("服务暂时不可用，稍后自动重试", false, nil)
        }
        if isKeychainPermission || isAuthExpired || isGenericAuth {
            return ("请在原工具中重新登录", true, .generic)
        }
        return ("服务暂时不可用，稍后自动重试", false, nil)
    }

    static func request(provider: String, connect: Bool) -> FetchResult {
        guard let worker = workers[provider] else { return FetchResult(data: nil, error: "不支持的服务") }
        return worker.request(provider: provider, connect: connect)
    }
    static func shutdownAll() { workers.values.forEach { $0.shutdown() } }
    private func start() throws -> (Process, FileHandle, FileHandle) {
        processLock.lock(); defer { processLock.unlock() }
        if let process, process.isRunning, let input, let output { return (process, input, output) }
        let child = Process()
        child.executableURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/HuixinQuotaBridge")
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (env["PATH"] ?? "")
        child.environment = env
        let stdin = Pipe(), stdout = Pipe()
        child.standardInput = stdin; child.standardOutput = stdout
        child.standardError = FileHandle.nullDevice
        try child.run()
        process = child; input = stdin.fileHandleForWriting; output = stdout.fileHandleForReading
        return (child, stdin.fileHandleForWriting, stdout.fileHandleForReading)
    }
    private func request(provider: String, connect: Bool) -> FetchResult {
        guard requestLock.try() else { return FetchResult(data: nil, error: "该服务正在同步") }
        defer { requestLock.unlock() }
        let started = Date()
        let timeout: TimeInterval = connect ? 120 : (provider == "codex" ? 12 : (provider == "workbuddy" ? 45 : 20))
        do {
            let (child, input, output) = try start()
            var data = try JSONSerialization.data(withJSONObject: ["provider": provider, "connect": connect])
            data.append(10)
            let terminate = DispatchWorkItem { if child.isRunning { child.terminate() } }
            let kill = DispatchWorkItem { if child.isRunning { Darwin.kill(child.processIdentifier, SIGKILL) } }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: terminate)
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout + 1, execute: kill)
            defer { terminate.cancel(); kill.cancel() }
            try input.write(contentsOf: data)
            var line = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while true {
                // POSIX read returns available pipe bytes immediately; FileHandle.read(upToCount:)
                // may wait for the requested count even after a complete JSON line has arrived.
                let count = buffer.withUnsafeMutableBytes { Darwin.read(output.fileDescriptor, $0.baseAddress, $0.count) }
                if count < 0 {
                    if errno == EINTR { continue }
                    throw CocoaError(.fileReadUnknown)
                }
                if count == 0 { break }
                line.append(contentsOf: buffer.prefix(count))
                if let end = line.firstIndex(of: 10) { line = line.prefix(upTo: end); break }
                if line.count > 4 * 1024 * 1024 { throw CocoaError(.fileReadTooLarge) }
            }
            guard !line.isEmpty else { throw CocoaError(.fileReadUnknown) }
            if let response = (try? JSONSerialization.jsonObject(with: line)) as? [[String: Any]],
               let error = response.first?["error"] as? String {
                let classified = Self.classifyError(provider: provider, error: error)
                let duration = String(format: "%.2f", Date().timeIntervalSince(started))
                let summary = String(error.replacingOccurrences(of: "\n", with: " ").prefix(180))
                Self.recordDiagnostic("provider=\(provider) connect=\(connect) duration=\(duration)s needsConnection=\(classified.needsConnection) kind=\(classified.kind?.rawValue ?? "none") err=\(summary)")
                return FetchResult(data: nil, error: classified.message, needsConnection: classified.needsConnection, connectionIssue: classified.kind)
            }
            return FetchResult(data: line, error: nil)
        } catch {
            shutdown()
            let duration = String(format: "%.2f", Date().timeIntervalSince(started))
            let timedOut = Date().timeIntervalSince(started) >= timeout - 0.5
            Self.recordDiagnostic("provider=\(provider) connect=\(connect) duration=\(duration)s reset=true timedOut=\(timedOut)")
            return FetchResult(data: nil, error: timedOut ? "本次同步超时，保留上次数据并稍后重试" : "读取进程已重置，稍后自动重试")
        }
    }
    private func shutdown() {
        processLock.lock(); defer { processLock.unlock() }
        if let process, process.isRunning { Darwin.kill(process.processIdentifier, SIGKILL) }
        try? input?.close()
        process = nil; input = nil; output = nil
    }
}
