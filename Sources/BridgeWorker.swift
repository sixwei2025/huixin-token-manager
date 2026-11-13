import Foundation

/// The upstream engine keeps cookie sessions in memory for ad-hoc apps. Both Connect and Usage
/// therefore share this owned process; no cookies are exported to files, argv or application logs.
final class BridgeWorker {
    static let shared = BridgeWorker()
    private let lock = NSLock()
    private var process: Process?
    private var input: FileHandle?
    private var output: FileHandle?

    private func start() throws {
        if process?.isRunning == true { return }
        let child = Process()
        child.executableURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/HuixinQuotaBridge")
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (env["PATH"] ?? "")
        child.environment = env
        let stdin = Pipe(), stdout = Pipe()
        child.standardInput = stdin
        child.standardOutput = stdout
        child.standardError = FileHandle.nullDevice
        try child.run()
        process = child
        input = stdin.fileHandleForWriting
        output = stdout.fileHandleForReading
    }
    func request(provider: String, connect: Bool) -> FetchResult {
        lock.lock()
        defer { lock.unlock() }
        do {
            try start()
            guard let child = process, let input, let output else { throw CocoaError(.fileReadUnknown) }
            var data = try JSONSerialization.data(withJSONObject: ["provider": provider, "connect": connect])
            data.append(10)
            let timeout: TimeInterval = connect ? 120 : 48
            let terminate = DispatchWorkItem { if child.isRunning { child.terminate() } }
            let kill = DispatchWorkItem { if child.isRunning { Darwin.kill(child.processIdentifier, SIGKILL) } }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: terminate)
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout + 3, execute: kill)
            defer { terminate.cancel(); kill.cancel() }
            try input.write(contentsOf: data)
            var line = Data()
            while let byte = try output.read(upToCount: 1), !byte.isEmpty {
                if byte[0] == 10 { break }
                line.append(byte)
                if line.count > 4 * 1024 * 1024 { throw CocoaError(.fileReadTooLarge) }
            }
            guard !line.isEmpty else { throw CocoaError(.fileReadUnknown) }
            if let response = (try? JSONSerialization.jsonObject(with: line)) as? [[String: Any]],
               let error = response.first?["error"] as? String {
                if CommandLine.arguments.contains("--diagnostics") {
                    let safe = error.replacingOccurrences(of: #"[\w.+-]+@[\w.-]+"#, with: "[email]", options: .regularExpression)
                    print("Browser result \(provider) connect=\(connect) error=\(safe.prefix(400))")
                    fflush(stdout)
                }
                let lower = error.lowercased()
                let message: String
                if lower.contains("keychain") || lower.contains("cookie") || lower.contains("session") {
                    message = "需要连接浏览器，请点“连接与来源”"
                } else { message = "读取失败，请确认网页登录后重试连接" }
                return FetchResult(data: nil, error: message)
            }
            if CommandLine.arguments.contains("--diagnostics") { print("Browser result \(provider) connect=\(connect) success"); fflush(stdout) }
            return FetchResult(data: line, error: nil)
        } catch {
            if process?.isRunning == true { process?.terminate() }
            process = nil
            input = nil; output = nil
            return FetchResult(data: nil, error: "浏览器读取进程未就绪，请重新连接")
        }
    }
    func shutdown() {
        lock.lock(); defer { lock.unlock() }
        try? input?.close()
        if process?.isRunning == true { process?.terminate() }
        process = nil; input = nil; output = nil
    }
}
