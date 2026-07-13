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
        guard usage != nil, lastUsageObservedAt != nil else { return .waiting }
        let freshKinds = ClaudeUsageWindowKind.allCases.filter {
            freshWindow($0, now: now) != nil
        }
        if freshKinds.isEmpty {
            return .stale
        }
        return freshKinds.count == ClaudeUsageWindowKind.allCases.count ? .available : .partial
    }

    public func freshMaxUsedPercent(now: Date = Date()) -> Double? {
        guard status(now: now) == .available || status(now: now) == .partial else { return nil }
        return ClaudeUsageWindowKind.allCases
            .compactMap { freshWindow($0, now: now)?.usedPercent }
            .max()
    }

    public func freshWindow(
        _ kind: ClaudeUsageWindowKind,
        now: Date = Date()
    ) -> ClaudeUsageWindowSnapshot? {
        guard issue == nil,
              let usage,
              let lastUsageObservedAt else { return nil }
        let timestamp = Int(now.timeIntervalSince1970)
        guard timestamp - lastUsageObservedAt <= staleAfterSeconds,
              let window = usage.window(kind),
              window.usedPercent != nil,
              window.resetsAt.map({ $0 > timestamp }) ?? true else {
            return nil
        }
        return window
    }
}

public enum ClaudeUsageIngestResult: Equatable, Sendable {
    case stored(ClaudeStatusLineSnapshot)
    case failed(code: String)
}

public struct ClaudeUsageStoredState: Equatable, Sendable {
    public let cacheSnapshot: ClaudeUsageCacheSnapshot?
    public let history: ClaudeUsageHistory

    public init(
        cacheSnapshot: ClaudeUsageCacheSnapshot?,
        history: ClaudeUsageHistory
    ) {
        self.cacheSnapshot = cacheSnapshot
        self.history = history
    }
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
        try withFileLock(type: Int16(F_RDLCK)) {
            try readCacheUnlocked()
        }
    }

    public func readHistory() throws -> ClaudeUsageHistory {
        try withFileLock(type: Int16(F_RDLCK)) {
            try readHistoryUnlocked()
        }
    }

    public func readState() throws -> ClaudeUsageStoredState {
        try withFileLock(type: Int16(F_RDLCK)) {
            let cacheSnapshot = fileManager.fileExists(atPath: fileURL.path)
                ? try readCacheUnlocked()
                : nil
            return ClaudeUsageStoredState(
                cacheSnapshot: cacheSnapshot,
                history: try readHistoryUnlocked()
            )
        }
    }

    private func readHistoryUnlocked() throws -> ClaudeUsageHistory {
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
        try withFileLock(type: Int16(F_WRLCK)) {
            let existing = try? readCacheUnlocked()
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
        try withFileLock(type: Int16(F_WRLCK)) {
            let existing = try? readCacheUnlocked()
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
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        try dataWriter(try encoder.encode(snapshot), fileURL, [.atomic])
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    private func readCacheUnlocked() throws -> ClaudeUsageCacheSnapshot {
        try decoder.decode(ClaudeUsageCacheSnapshot.self, from: Data(contentsOf: fileURL))
    }

    private func withFileLock<T>(
        type: Int16,
        _ body: () throws -> T
    ) throws -> T {
        Self.processLock.lock()
        defer { Self.processLock.unlock() }
        let directory = lockFileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        let descriptor = lockFileURL.path.withCString {
            Darwin.open($0, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        }
        guard descriptor >= 0 else {
            throw CocoaError(.fileWriteUnknown)
        }
        defer { Darwin.close(descriptor) }
        guard Darwin.fchmod(descriptor, S_IRUSR | S_IWUSR) == 0 else {
            throw CocoaError(.fileWriteUnknown)
        }
        var lock = Darwin.flock()
        lock.l_type = type
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
        switch code {
        case "status_line_decode_failed",
             "invalid_usage_percent",
             "invalid_reset_timestamp",
             "status_line_too_large":
            return code
        default:
            return "unknown_error"
        }
    }
}
