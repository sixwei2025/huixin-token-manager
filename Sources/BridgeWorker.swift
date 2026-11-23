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
        let timeout: TimeInterval = connect ? 120 : (provider == "codex" ? 12 : (provider == "workbuddy" ? 40 : 20))
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
                let lower = error.lowercased()
                let needsConnection = ["keychain", "cookie", "session", "unauthorized", "401", "log in", "login", "authentication"].contains { lower.contains($0) }
                let message = provider == "workbuddy" && needsConnection
                    ? "需要连接 Chrome 中已登录的 WorkBuddy"
                    : needsConnection ? "请在原工具中重新登录" : "服务暂时不可用，稍后自动重试"
                return FetchResult(data: nil, error: message, needsConnection: needsConnection)
            }
            return FetchResult(data: line, error: nil)
        } catch {
            shutdown()
            let timedOut = Date().timeIntervalSince(started) >= timeout - 0.5
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
