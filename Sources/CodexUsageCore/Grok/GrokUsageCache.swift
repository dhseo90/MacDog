import Darwin
import Foundation

public enum GrokUsageCacheStatus: String, Equatable, Sendable {
    case waiting
    case available
    case stale
    case error
}

public struct GrokUsageCacheIssue: Codable, Equatable, Sendable {
    public let code: String
    public let recordedAt: Int

    public init(code: String, recordedAt: Int) {
        self.code = code
        self.recordedAt = recordedAt
    }
}

public struct GrokUsageWeeklyWindow: Codable, Equatable, Sendable {
    public let usedPercent: Double
    public let remainingPercent: Double
    public let resetsAt: Int?

    public init?(usedPercent: Double, remainingPercent _: Double? = nil, resetsAt: Int?) {
        guard usedPercent.isFinite, (0...100).contains(usedPercent) else { return nil }
        self.usedPercent = usedPercent
        self.remainingPercent = 100 - usedPercent
        self.resetsAt = resetsAt.flatMap { $0 > 0 ? $0 : nil }
    }
}

public struct GrokUsageCacheSnapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public static let allowedSource = "unofficial-cli-billing"

    public let schemaVersion: Int
    public let source: String
    public let fetchedAt: Int
    public let lastUsageObservedAt: Int?
    public let staleAfterSeconds: Int
    public let weekly: GrokUsageWeeklyWindow?
    public let issue: GrokUsageCacheIssue?

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        source: String = Self.allowedSource,
        fetchedAt: Int,
        lastUsageObservedAt: Int?,
        staleAfterSeconds: Int,
        weekly: GrokUsageWeeklyWindow?,
        issue: GrokUsageCacheIssue?
    ) {
        self.schemaVersion = schemaVersion
        self.source = source == Self.allowedSource ? source : Self.allowedSource
        self.fetchedAt = fetchedAt
        self.lastUsageObservedAt = lastUsageObservedAt
        self.staleAfterSeconds = staleAfterSeconds
        self.weekly = weekly
        self.issue = issue
    }

    public func status(now: Date = Date()) -> GrokUsageCacheStatus {
        if issue != nil { return .error }
        guard weekly != nil, let lastUsageObservedAt else { return .waiting }
        let timestamp = Int(now.timeIntervalSince1970)
        if timestamp - lastUsageObservedAt > staleAfterSeconds {
            return .stale
        }
        if let resetsAt = weekly?.resetsAt, resetsAt <= timestamp {
            return .stale
        }
        return .available
    }

    public func freshWeekly(now: Date = Date()) -> GrokUsageWeeklyWindow? {
        guard status(now: now) == .available else { return nil }
        return weekly
    }
}

public enum GrokUsageIngestResult: Equatable, Sendable {
    case stored(GrokUsageWeeklyWindow)
    case failed(code: String)
}

public struct GrokUsageStoredState: Equatable, Sendable {
    public let cacheSnapshot: GrokUsageCacheSnapshot?
    public let history: GrokUsageHistory

    public init(
        cacheSnapshot: GrokUsageCacheSnapshot?,
        history: GrokUsageHistory
    ) {
        self.cacheSnapshot = cacheSnapshot
        self.history = history
    }
}

public struct GrokUsageCacheStore {
    public static let defaultStaleAfterSeconds = 180
    public static let defaultSource = GrokUsageCacheSnapshot.allowedSource

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
        self.historyFileURL = historyFileURL ?? GrokUsageHistoryStore.defaultFileURL(
            adjacentToCacheFileURL: fileURL
        )
        self.lockFileURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent("grok-usage.lock")
        self.fileManager = fileManager
        self.dateProvider = dateProvider
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
        self.dataWriter = dataWriter
    }

    public static func defaultFileURL() -> URL {
        CodexUsageCacheStore.defaultApplicationSupportDirectoryURL()
            .appendingPathComponent("grok-usage.json")
    }

    public func read() throws -> GrokUsageCacheSnapshot {
        try withFileLock(type: Int16(F_RDLCK)) {
            try readCacheUnlocked()
        }
    }

    public func readHistory() throws -> GrokUsageHistory {
        try withFileLock(type: Int16(F_RDLCK)) {
            try readHistoryUnlocked()
        }
    }

    public func readState() throws -> GrokUsageStoredState {
        try withFileLock(type: Int16(F_RDLCK)) {
            let cacheSnapshot = fileManager.fileExists(atPath: fileURL.path)
                ? try readCacheUnlocked()
                : nil
            return GrokUsageStoredState(
                cacheSnapshot: cacheSnapshot,
                history: try readHistoryUnlocked()
            )
        }
    }

    public func record(
        _ weekly: GrokUsageWeeklyWindow,
        at timestamp: Int? = nil,
        staleAfterSeconds: Int = Self.defaultStaleAfterSeconds
    ) throws -> GrokUsageIngestResult {
        let fetchedAt = timestamp ?? Int(dateProvider().timeIntervalSince1970)
        try withFileLock(type: Int16(F_WRLCK)) {
            if let sample = GrokUsageHistorySample(
                recordedAt: fetchedAt,
                usedPercent: weekly.usedPercent,
                remainingPercent: weekly.remainingPercent,
                resetsAt: weekly.resetsAt
            ) {
                _ = try GrokUsageHistoryStore(
                    fileURL: historyFileURL,
                    fileManager: fileManager,
                    dataWriter: dataWriter
                ).append([sample])
            }
            try write(GrokUsageCacheSnapshot(
                fetchedAt: fetchedAt,
                lastUsageObservedAt: fetchedAt,
                staleAfterSeconds: staleAfterSeconds,
                weekly: weekly,
                issue: nil
            ))
        }
        return .stored(weekly)
    }

    public func recordFailure(
        code: String,
        at timestamp: Int? = nil,
        staleAfterSeconds: Int = Self.defaultStaleAfterSeconds
    ) throws -> GrokUsageIngestResult {
        let fetchedAt = timestamp ?? Int(dateProvider().timeIntervalSince1970)
        let sanitized = Self.sanitizedIssueCode(code)
        try withFileLock(type: Int16(F_WRLCK)) {
            let existing = try? readCacheUnlocked()
            try write(GrokUsageCacheSnapshot(
                fetchedAt: fetchedAt,
                lastUsageObservedAt: existing?.lastUsageObservedAt,
                staleAfterSeconds: staleAfterSeconds,
                weekly: existing?.weekly,
                issue: GrokUsageCacheIssue(code: sanitized, recordedAt: fetchedAt)
            ))
        }
        return .failed(code: sanitized)
    }

    private func write(_ snapshot: GrokUsageCacheSnapshot) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        try dataWriter(try encoder.encode(snapshot), fileURL, [.atomic])
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    private func readCacheUnlocked() throws -> GrokUsageCacheSnapshot {
        try decoder.decode(GrokUsageCacheSnapshot.self, from: Data(contentsOf: fileURL))
    }

    private func readHistoryUnlocked() throws -> GrokUsageHistory {
        try GrokUsageHistoryStore(
            fileURL: historyFileURL,
            fileManager: fileManager,
            dataWriter: dataWriter
        ).read()
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
        case "weekly-window-missing",
             "billing-decode-failed",
             "billing-too-large",
             "auth-unavailable",
             "request-failed":
            return code
        default:
            return "unknown_error"
        }
    }
}
