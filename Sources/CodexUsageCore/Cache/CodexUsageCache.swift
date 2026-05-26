import Foundation

public struct CodexUsageCacheSnapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let cachedAt: Int
    public let staleAfterSeconds: Int
    public let report: CodexUsageReport?
    public let error: CodexUsageCacheError?

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        cachedAt: Int,
        staleAfterSeconds: Int,
        report: CodexUsageReport?,
        error: CodexUsageCacheError?
    ) {
        self.schemaVersion = schemaVersion
        self.cachedAt = cachedAt
        self.staleAfterSeconds = staleAfterSeconds
        self.report = report
        self.error = error
    }

    public func isStale(now: Date = Date()) -> Bool {
        guard report != nil else { return true }
        let age = Int(now.timeIntervalSince1970) - cachedAt
        return age > staleAfterSeconds || error != nil
    }
}

public struct CodexUsageCacheError: Codable, Equatable, Sendable {
    public let message: String
    public let recordedAt: Int

    public init(message: String, recordedAt: Int) {
        self.message = message
        self.recordedAt = recordedAt
    }
}

public struct CodexUsageCacheStore {
    public static let defaultAppGroupIdentifier = "group.com.dhseo.mycodex.CodexUsageMonitor"
    public static let cacheAgentRefreshIntervalSeconds = 300
    public static let defaultStaleAfterSeconds = cacheAgentRefreshIntervalSeconds + 60

    private let fileURL: URL
    private let fileManager: FileManager
    private let dateProvider: () -> Date
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        fileURL: URL = Self.defaultFileURL(),
        fileManager: FileManager = .default,
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        self.dateProvider = dateProvider
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
    }

    public static func defaultFileURL() -> URL {
        defaultApplicationSupportFileURL()
    }

    public static func defaultFileURL(appGroupIdentifier: String?) -> URL {
        if let appGroupIdentifier,
           let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
           ) {
            return containerURL.appendingPathComponent("usage.json")
        }

        return defaultApplicationSupportFileURL()
    }

    public static func defaultApplicationSupportFileURL() -> URL {
        let directory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("CodexUsageMonitor", isDirectory: true)
        return directory.appendingPathComponent("usage.json")
    }

    public func read() throws -> CodexUsageCacheSnapshot {
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(CodexUsageCacheSnapshot.self, from: data)
    }

    public func writeSuccess(
        report: CodexUsageReport,
        staleAfterSeconds: Int = Self.defaultStaleAfterSeconds
    ) throws {
        let now = Int(dateProvider().timeIntervalSince1970)
        let snapshot = CodexUsageCacheSnapshot(
            cachedAt: now,
            staleAfterSeconds: staleAfterSeconds,
            report: report,
            error: nil
        )
        try write(snapshot)
    }

    public func writeFailure(
        message: String,
        staleAfterSeconds: Int = Self.defaultStaleAfterSeconds
    ) throws {
        let now = Int(dateProvider().timeIntervalSince1970)
        let existingReport = try? read().report
        let snapshot = CodexUsageCacheSnapshot(
            cachedAt: now,
            staleAfterSeconds: staleAfterSeconds,
            report: existingReport,
            error: CodexUsageCacheError(message: message, recordedAt: now)
        )
        try write(snapshot)
    }

    private func write(_ snapshot: CodexUsageCacheSnapshot) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: [.atomic])
    }
}
