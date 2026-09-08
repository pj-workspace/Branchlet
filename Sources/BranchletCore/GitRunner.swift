import Foundation
import Darwin

public struct GitOutput: Sendable {
    public let data: Data
    public let error: String
    public let code: Int32
    public let truncated: Bool
    public var text: String { String(decoding: data, as: UTF8.self) }
    public func checked() throws -> GitOutput {
        guard code == 0 else { throw GitError.commandFailed(error.isEmpty ? "Git 退出码 \(code)" : error) }
        guard !truncated else { throw GitError.commandFailed("Git 输出过大，请缩小查看范围。") }
        return self
    }
}

public enum GitError: LocalizedError, Sendable {
    case commandFailed(String), timeout
    public var errorDescription: String? {
        switch self {
        case .commandFailed(let message): message.trimmingCharacters(in: .whitespacesAndNewlines)
        case .timeout: "Git 操作超时，请检查仓库或远程连接。"
        }
    }
}

/// Runs argv directly, with no shell, optional index writes, interactive prompts or pipe backpressure.
public struct GitRunner: Sendable {
    public init() {}
    public func run(_ arguments: [String], at path: String, timeout: TimeInterval = 20, limit: Int = 8_000_000) async throws -> GitOutput {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do { continuation.resume(returning: try Execution(arguments: arguments, path: path, timeout: timeout, limit: limit).run()) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }
}

private final class Execution: @unchecked Sendable {
    let process = Process()
    let lock = NSLock()
    var timedOut = false
    let timeout: TimeInterval
    let limit: Int

    init(arguments: [String], path: String, timeout: TimeInterval, limit: Int) {
        self.timeout = timeout; self.limit = limit
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["--no-optional-locks", "-c", "core.fsmonitor=false", "-c", "color.ui=false", "-C", path] + arguments
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_TERMINAL_PROMPT"] = "0"
        environment["GIT_OPTIONAL_LOCKS"] = "0"
        environment["GIT_LITERAL_PATHSPECS"] = "1"
        environment["LC_ALL"] = "en_US.UTF-8"
        environment["GIT_PAGER"] = "cat"
        environment["PAGER"] = "cat"
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
    }

    func run() throws -> GitOutput {
        // Private temporary capture files avoid deadlocks when a diff or an SSH child fills a pipe.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("branchlet-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: directory) }
        let outputURL = directory.appendingPathComponent("stdout")
        let errorURL = directory.appendingPathComponent("stderr")
        FileManager.default.createFile(atPath: outputURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
        FileManager.default.createFile(atPath: errorURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
        let out = try FileHandle(forWritingTo: outputURL), err = try FileHandle(forWritingTo: errorURL)
        defer { try? out.close(); try? err.close() }
        process.standardOutput = out; process.standardError = err
        try process.run()
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + timeout)
        timer.setEventHandler { [self] in
            lock.lock(); defer { lock.unlock() }
            if process.isRunning { timedOut = true; process.terminate() }
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) { [self] in
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            }
        }
        timer.resume()
        process.waitUntilExit()
        timer.cancel()
        lock.lock(); let expired = timedOut; lock.unlock()
        if expired { throw GitError.timeout }
        let reader = try FileHandle(forReadingFrom: outputURL)
        let errorReader = try FileHandle(forReadingFrom: errorURL)
        defer { try? reader.close(); try? errorReader.close() }
        let data = try reader.read(upToCount: limit + 1) ?? Data()
        let errorData = try errorReader.read(upToCount: 8_192) ?? Data()
        return GitOutput(data: Data(data.prefix(limit)), error: String(decoding: errorData, as: UTF8.self), code: process.terminationStatus, truncated: data.count > limit)
    }
}
