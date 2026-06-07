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

public enum CodexUsageWeeklyHistoryWriteDisposition: String, Equatable, Sendable {
    case stored
    case skipped
    case unavailable
}

public struct CodexUsageWeeklyHistoryWriteResult: Equatable, Sendable {
    public let disposition: CodexUsageWeeklyHistoryWriteDisposition
    public let fileURL: URL
    public let recordedAt: Int?
    public let recordingStartedAt: Int?
    public let remainingPercent: Double?
    public let resetsAt: Int?

    public init(
        disposition: CodexUsageWeeklyHistoryWriteDisposition,
        fileURL: URL,
        recordedAt: Int?,
        recordingStartedAt: Int?,
        remainingPercent: Double?,
        resetsAt: Int?
    ) {
        self.disposition = disposition
        self.fileURL = fileURL
        self.recordedAt = recordedAt
        self.recordingStartedAt = recordingStartedAt
        self.remainingPercent = remainingPercent
        self.resetsAt = resetsAt
    }
}

public struct CodexUsageCacheWriteResult: Equatable, Sendable {
    public let cachedAt: Int
    public let cacheFileURL: URL
    public let weeklyHistory: CodexUsageWeeklyHistoryWriteResult

    public init(
        cachedAt: Int,
        cacheFileURL: URL,
        weeklyHistory: CodexUsageWeeklyHistoryWriteResult
    ) {
        self.cachedAt = cachedAt
        self.cacheFileURL = cacheFileURL
        self.weeklyHistory = weeklyHistory
    }
}

public struct CodexUsageCacheStore {
    public static let defaultAppGroupIdentifier = "group.com.dhseo.macdog.MacDog"
    public static let cacheAgentRefreshIntervalSeconds = 60
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

        if appGroupIdentifier == defaultAppGroupIdentifier {
            return defaultAppGroupContainerFallbackFileURL()
        }

        return defaultApplicationSupportFileURL()
    }

    public static func defaultSharedFileURL() -> URL {
        defaultFileURL(appGroupIdentifier: defaultAppGroupIdentifier)
    }

    public static func defaultMirroredFileURLs() -> [URL] {
        uniqueFileURLs([
            defaultApplicationSupportFileURL(),
            resolvedAppGroupContainerFileURL()
        ].compactMap { $0 })
    }

    public static func defaultApplicationSupportDirectoryURL() -> URL {
        FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("MacDog", isDirectory: true)
    }

    public static func defaultApplicationSupportFileURL() -> URL {
        defaultApplicationSupportDirectoryURL().appendingPathComponent("usage.json")
    }

    private static func defaultAppGroupContainerFallbackFileURL() -> URL {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Group Containers", isDirectory: true)
            .appendingPathComponent(defaultAppGroupIdentifier, isDirectory: true)
        return directory.appendingPathComponent("usage.json")
    }

    private static func resolvedAppGroupContainerFileURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: defaultAppGroupIdentifier)?
            .appendingPathComponent("usage.json")
    }

    private static func uniqueFileURLs(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        var result: [URL] = []

        for url in urls {
            let key = url.standardizedFileURL.path
            if seen.insert(key).inserted {
                result.append(url)
            }
        }

        return result
    }

    public func read() throws -> CodexUsageCacheSnapshot {
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(CodexUsageCacheSnapshot.self, from: data)
    }

    @discardableResult
    public func writeSuccess(
        report: CodexUsageReport,
        staleAfterSeconds: Int = Self.defaultStaleAfterSeconds
    ) throws -> CodexUsageCacheWriteResult {
        try report.validateRequiredCodexUsageWindows()
        let now = Int(dateProvider().timeIntervalSince1970)
        let snapshot = CodexUsageCacheSnapshot(
            cachedAt: now,
            staleAfterSeconds: staleAfterSeconds,
            report: report,
            error: nil
        )
        try write(snapshot)
        let historyFileURL = CodexUsageWeeklyHistoryStore.defaultFileURL(adjacentToCacheFileURL: fileURL)
        let weeklyHistory: CodexUsageWeeklyHistoryWriteResult
        if let sample = CodexUsageWeeklyHistorySample(report: report, recordedAt: now) {
            let historyStore = CodexUsageWeeklyHistoryStore(
                fileURL: historyFileURL,
                fileManager: fileManager,
                dateProvider: dateProvider
            )
            let stored = try historyStore.append(sample)
            let recordingStartedAt = try? historyStore.read().samples
                .first {
                    $0.matchesResetWindow(
                        resetsAt: sample.resetsAt,
                        windowDurationMins: sample.windowDurationMins
                    )
                }?
                .recordedAt
            weeklyHistory = CodexUsageWeeklyHistoryWriteResult(
                disposition: stored ? .stored : .skipped,
                fileURL: historyFileURL,
                recordedAt: sample.recordedAt,
                recordingStartedAt: recordingStartedAt,
                remainingPercent: sample.remainingPercent,
                resetsAt: sample.resetsAt
            )
        } else {
            weeklyHistory = CodexUsageWeeklyHistoryWriteResult(
                disposition: .unavailable,
                fileURL: historyFileURL,
                recordedAt: nil,
                recordingStartedAt: nil,
                remainingPercent: nil,
                resetsAt: nil
            )
        }
        return CodexUsageCacheWriteResult(cachedAt: now, cacheFileURL: fileURL, weeklyHistory: weeklyHistory)
    }

    public func writeFailure(
        message: String,
        staleAfterSeconds: Int = Self.defaultStaleAfterSeconds
    ) throws {
        let now = Int(dateProvider().timeIntervalSince1970)
        let existingReport = Self.validReportForFailureSnapshot(from: try? read().report)
        let snapshot = CodexUsageCacheSnapshot(
            cachedAt: now,
            staleAfterSeconds: staleAfterSeconds,
            report: existingReport,
            error: CodexUsageCacheError(message: Self.redactedErrorMessage(message), recordedAt: now)
        )
        try write(snapshot)
    }

    private static func validReportForFailureSnapshot(from report: CodexUsageReport?) -> CodexUsageReport? {
        guard let report else { return nil }
        do {
            try report.validateRequiredCodexUsageWindows()
            return report
        } catch {
            return nil
        }
    }

    private func write(_ snapshot: CodexUsageCacheSnapshot) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: [.atomic])
    }

    private static func redactedErrorMessage(_ message: String) -> String {
        let patterns: [(pattern: String, replacement: String)] = [
            (
                #"(?i)(authorization\s*[:=]\s*)(bearer|basic)\s+[A-Za-z0-9._~+/=-]+"#,
                #"$1$2 <redacted>"#
            ),
            (
                #"(?i)(cookie\s*[:=]\s*)[^\n,]+"#,
                #"$1<redacted>"#
            ),
            (
                #"(?i)bearer\s+[A-Za-z0-9._~+/=-]+"#,
                #"Bearer <redacted>"#
            ),
            (
                #"(?i)(access[_-]?token|refresh[_-]?token|session[_-]?id|id[_-]?token|auth[_-]?token|api[_-]?key|client[_-]?secret|authorization|cookie)(["']?\s*[:=]\s*["']?)[^"',;\s}]+"#,
                #"$1$2<redacted>"#
            )
        ]

        return patterns.reduce(message) { current, rule in
            guard let regex = try? NSRegularExpression(pattern: rule.pattern) else {
                return current
            }
            let range = NSRange(current.startIndex..<current.endIndex, in: current)
            return regex.stringByReplacingMatches(
                in: current,
                range: range,
                withTemplate: rule.replacement
            )
        }
    }
}
