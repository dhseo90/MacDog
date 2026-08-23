import Darwin
import Foundation

public protocol GrokAuthFileLocking: Sendable {
    func withExclusiveLock<T>(
        adjacentTo authFileURL: URL,
        timeout: TimeInterval,
        _ body: () throws -> T
    ) throws -> T?
}

public struct GrokAuthFileLock: GrokAuthFileLocking {
    public init() {}

    public func withExclusiveLock<T>(
        adjacentTo authFileURL: URL,
        timeout: TimeInterval,
        _ body: () throws -> T
    ) throws -> T? {
        let lockURL = authFileURL
            .deletingLastPathComponent()
            .appendingPathComponent("auth.json.lock")
        try FileManager.default.createDirectory(
            at: lockURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let fd = lockURL.path.withCString { path in
            open(path, O_RDWR | O_CREAT, 0o600)
        }
        guard fd >= 0 else {
            return nil
        }
        defer {
            _ = flock(fd, LOCK_UN)
            close(fd)
        }

        let deadline = Date().addingTimeInterval(max(timeout, 0))
        while true {
            if flock(fd, LOCK_EX | LOCK_NB) == 0 {
                writeHolderInfo(fd: fd)
                return try body()
            }
            if Date() >= deadline {
                return nil
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
    }

    private func writeHolderInfo(fd: Int32) {
        let payload = "\(ProcessInfo.processInfo.processIdentifier):\(Int(Date().timeIntervalSince1970))\n"
        guard let data = payload.data(using: .utf8) else {
            return
        }
        _ = lseek(fd, 0, SEEK_SET)
        _ = ftruncate(fd, 0)
        data.withUnsafeBytes { buffer in
            guard let base = buffer.baseAddress else {
                return
            }
            _ = write(fd, base, buffer.count)
        }
    }
}
