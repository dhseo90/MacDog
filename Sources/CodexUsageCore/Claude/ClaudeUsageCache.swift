import Darwin
import Foundation

public enum ClaudeUsageCacheStatus: String, Equatable, Sendable {
    case waiting
    case partial
    case available
    case stale
    case error
}

public struct ClaudeUsageCacheIssue: Codable, Equatable, Sendable {
    public let code: String
    public let recordedAt: Int

    public init(code: String, recordedAt: Int) {
        self.code = code
        self.recordedAt = recordedAt
    }
}

public struct ClaudeUsageCacheSnapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let lastEventAt: Int
    public let lastUsageObservedAt: Int?
    public let staleAfterSeconds: Int
    public let usage: ClaudeStatusLineSnapshot?
    public let issue: ClaudeUsageCacheIssue?

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        lastEventAt: Int,
        lastUsageObservedAt: Int?,
        staleAfterSeconds: Int,
        usage: ClaudeStatusLineSnapshot?,
        issue: ClaudeUsageCacheIssue?
    ) {
        self.schemaVersion = schemaVersion
        self.lastEventAt = lastEventAt
        self.lastUsageObservedAt = lastUsageObservedAt
        self.staleAfterSeconds = staleAfterSeconds
        self.usage = usage
        self.issue = issue
    }

    public func status(now: Date = Date()) -> ClaudeUsageCacheStatus {
        if issue != nil { return .error }
        guard let usage, let lastUsageObservedAt else { return .waiting }
        let timestamp = Int(now.timeIntervalSince1970)
        if timestamp - lastUsageObservedAt > staleAfterSeconds ||
            freshWindows(now: timestamp).isEmpty {
            return .stale
        }
        return usage.fiveHour == nil || usage.sevenDay == nil ? .partial : .available
    }

    public func freshMaxUsedPercent(now: Date = Date()) -> Double? {
        let timestamp = Int(now.timeIntervalSince1970)
        guard status(now: now) == .available || status(now: now) == .partial else { return nil }
        return freshWindows(now: timestamp).compactMap(\.usedPercent).max()
    }

    private func freshWindows(now: Int) -> [ClaudeUsageWindowSnapshot] {
        guard let usage else { return [] }
        return [usage.fiveHour, usage.sevenDay]
            .compactMap(\.self)
            .filter { window in
                window.usedPercent != nil && (window.resetsAt.map { $0 > now } ?? true)
            }
    }
}

public enum ClaudeUsageIngestResult: Equatable, Sendable {
    case stored(ClaudeStatusLineSnapshot)
    case failed(code: String)
}

public struct ClaudeUsageCacheStore {
    public static let defaultStaleAfterSeconds = 15 * 60
    public static let maximumStatusLineBytes = 1_048_576

    public let fileURL: URL
    public let historyFileURL: URL
    private let lockFileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let dateProvider: () -> Date
    private let dataWriter: (Data, URL, Data.WritingOptions) throws -> Void
    private static let processLock = NSLock()

    public init(
        fileURL: URL = Self.defaultFileURL(),
        historyFileURL: URL? = nil,
        fileManager: FileManager = .default,
        dateProvider: @escaping () -> Date = Date.init,
        dataWriter: @escaping (Data, URL, Data.WritingOptions) throws -> Void = {
            try $0.write(to: $1, options: $2)
        }
    ) {
        self.fileURL = fileURL
        self.historyFileURL = historyFileURL ?? ClaudeUsageHistoryStore.defaultFileURL(
            adjacentToCacheFileURL: fileURL
        )
        self.lockFileURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent("claude-usage.lock")
        self.fileManager = fileManager
        self.dateProvider = dateProvider
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
        self.dataWriter = dataWriter
    }

    public static func defaultFileURL() -> URL {
        CodexUsageCacheStore.defaultApplicationSupportDirectoryURL()
            .appendingPathComponent("claude-usage.json")
    }

    public func read() throws -> ClaudeUsageCacheSnapshot {
        try decoder.decode(ClaudeUsageCacheSnapshot.self, from: Data(contentsOf: fileURL))
    }

    public func readHistory() throws -> ClaudeUsageHistory {
        try ClaudeUsageHistoryStore(
            fileURL: historyFileURL,
            fileManager: fileManager,
            dataWriter: dataWriter
        ).read()
    }

    public func ingest(
        statusLineData: Data,
        staleAfterSeconds: Int = Self.defaultStaleAfterSeconds
    ) throws -> ClaudeUsageIngestResult {
        let observedAt = Int(dateProvider().timeIntervalSince1970)
        guard statusLineData.count <= Self.maximumStatusLineBytes else {
            try recordFailure(code: "status_line_too_large", at: observedAt, staleAfterSeconds: staleAfterSeconds)
            return .failed(code: "status_line_too_large")
        }
        do {
            let snapshot = try ClaudeStatusLineSanitizer().snapshot(
                from: statusLineData,
                observedAt: observedAt
            )
            try record(snapshot, staleAfterSeconds: staleAfterSeconds)
            return .stored(snapshot)
        } catch let error as ClaudeStatusLineSanitizationError {
            try recordFailure(code: error.cacheCode, at: observedAt, staleAfterSeconds: staleAfterSeconds)
            return .failed(code: error.cacheCode)
        }
    }

    public func record(
        _ incoming: ClaudeStatusLineSnapshot,
        staleAfterSeconds: Int = Self.defaultStaleAfterSeconds
    ) throws {
        try withExclusiveLock {
            let existing = try? read()
            let persistedUsage = incoming.hasUsageData ? incoming : existing?.usage
            let usageObservedAt = incoming.hasUsageData
                ? incoming.observedAt
                : existing?.lastUsageObservedAt

            if incoming.hasUsageData {
                let samples = ClaudeUsageWindowKind.allCases.compactMap { kind -> ClaudeUsageHistorySample? in
                    guard let window = incoming.window(kind),
                          let usedPercent = window.usedPercent,
                          let resetsAt = window.resetsAt else { return nil }
                    return ClaudeUsageHistorySample(
                        kind: kind,
                        recordedAt: incoming.observedAt,
                        usedPercent: usedPercent,
                        resetsAt: resetsAt
                    )
                }
                _ = try ClaudeUsageHistoryStore(
                    fileURL: historyFileURL,
                    fileManager: fileManager,
                    dataWriter: dataWriter
                ).append(samples)
            }

            try write(ClaudeUsageCacheSnapshot(
                lastEventAt: incoming.observedAt,
                lastUsageObservedAt: usageObservedAt,
                staleAfterSeconds: staleAfterSeconds,
                usage: persistedUsage,
                issue: nil
            ))
        }
    }

    public func recordFailure(
        code: String,
        at timestamp: Int,
        staleAfterSeconds: Int = Self.defaultStaleAfterSeconds
    ) throws {
        try withExclusiveLock {
            let existing = try? read()
            try write(ClaudeUsageCacheSnapshot(
                lastEventAt: timestamp,
                lastUsageObservedAt: existing?.lastUsageObservedAt,
                staleAfterSeconds: staleAfterSeconds,
                usage: existing?.usage,
                issue: ClaudeUsageCacheIssue(code: Self.sanitizedIssueCode(code), recordedAt: timestamp)
            ))
        }
    }

    private func write(_ snapshot: ClaudeUsageCacheSnapshot) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try? fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        try dataWriter(try encoder.encode(snapshot), fileURL, [.atomic])
        try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    private func withExclusiveLock<T>(_ body: () throws -> T) throws -> T {
        Self.processLock.lock()
        defer { Self.processLock.unlock() }
        let directory = lockFileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let descriptor = lockFileURL.path.withCString {
            Darwin.open($0, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        }
        guard descriptor >= 0 else {
            throw CocoaError(.fileWriteUnknown)
        }
        defer { Darwin.close(descriptor) }
        var lock = Darwin.flock()
        lock.l_type = Int16(F_WRLCK)
        lock.l_whence = Int16(SEEK_SET)
        lock.l_start = 0
        lock.l_len = 0
        guard Darwin.fcntl(descriptor, F_SETLKW, &lock) == 0 else {
            throw CocoaError(.fileWriteUnknown)
        }
        defer {
            lock.l_type = Int16(F_UNLCK)
            _ = Darwin.fcntl(descriptor, F_SETLK, &lock)
        }
        return try body()
    }

    private static func sanitizedIssueCode(_ code: String) -> String {
        let allowed = code.unicodeScalars.filter {
            CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_").contains($0)
        }
        let sanitized = String(String.UnicodeScalarView(allowed)).prefix(64)
        return sanitized.isEmpty ? "unknown_error" : String(sanitized)
    }
}
