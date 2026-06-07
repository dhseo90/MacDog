import Foundation

public struct CodexUsageWeeklyHistory: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public static let empty = CodexUsageWeeklyHistory(samples: [])

    public let schemaVersion: Int
    public let samples: [CodexUsageWeeklyHistorySample]

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        samples: [CodexUsageWeeklyHistorySample]
    ) {
        self.schemaVersion = schemaVersion
        self.samples = samples.sorted { $0.recordedAt < $1.recordedAt }
    }
}

public struct CodexUsageWeeklyHistorySample: Codable, Equatable, Sendable {
    public static let resetWindowTimestampToleranceSeconds = 5 * 60

    public let recordedAt: Int
    public let usedPercent: Double
    public let remainingPercent: Double
    public let resetsAt: Int
    public let windowDurationMins: Int

    public init(
        recordedAt: Int,
        usedPercent: Double,
        remainingPercent: Double,
        resetsAt: Int,
        windowDurationMins: Int
    ) {
        self.recordedAt = recordedAt
        self.usedPercent = Self.clampedPercent(usedPercent)
        self.remainingPercent = Self.clampedPercent(remainingPercent)
        self.resetsAt = resetsAt
        self.windowDurationMins = windowDurationMins
    }

    public init?(report: CodexUsageReport, recordedAt: Int) {
        guard let weekly = report.codexLimit?.weekly,
              let resetsAt = weekly.resetsAt,
              let windowDurationMins = weekly.windowDurationMins,
              windowDurationMins > 0
        else {
            return nil
        }

        self.init(
            recordedAt: recordedAt,
            usedPercent: weekly.usedPercent,
            remainingPercent: weekly.remainingPercent,
            resetsAt: resetsAt,
            windowDurationMins: windowDurationMins
        )
    }

    public func matchesResetWindow(
        resetsAt targetResetsAt: Int,
        windowDurationMins targetWindowDurationMins: Int,
        toleranceSeconds: Int = Self.resetWindowTimestampToleranceSeconds
    ) -> Bool {
        guard windowDurationMins == targetWindowDurationMins else { return false }
        return abs(resetsAt - targetResetsAt) <= max(toleranceSeconds, 0)
    }

    private static func clampedPercent(_ value: Double) -> Double {
        min(max(value, 0), 100)
    }
}

public struct CodexUsageWeeklyHistoryStore {
    public static let fileName = "usage-weekly-history.json"
    public static let minimumSampleIntervalSeconds = 5 * 60
    public static let minimumRemainingPercentDelta = 0.25
    public static let defaultRetentionSeconds = 8 * 24 * 60 * 60

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
        CodexUsageCacheStore.defaultApplicationSupportDirectoryURL()
            .appendingPathComponent(fileName)
    }

    public static func defaultFileURL(adjacentToCacheFileURL cacheFileURL: URL) -> URL {
        cacheFileURL.deletingLastPathComponent().appendingPathComponent(fileName)
    }

    public func read() throws -> CodexUsageWeeklyHistory {
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(CodexUsageWeeklyHistory.self, from: data)
    }

    @discardableResult
    public func append(report: CodexUsageReport) throws -> Bool {
        let recordedAt = Int(dateProvider().timeIntervalSince1970)
        guard let sample = CodexUsageWeeklyHistorySample(report: report, recordedAt: recordedAt) else {
            return false
        }
        return try append(sample)
    }

    @discardableResult
    public func append(_ sample: CodexUsageWeeklyHistorySample) throws -> Bool {
        let existing = (try? read()) ?? .empty
        var retained = existing.samples
            .filter { sample.recordedAt - $0.recordedAt <= Self.defaultRetentionSeconds }
            .filter {
                !(
                    $0.recordedAt == sample.recordedAt &&
                        $0.matchesResetWindow(
                            resetsAt: sample.resetsAt,
                            windowDurationMins: sample.windowDurationMins
                        )
                )
            }

        if shouldSkip(sample: sample, after: retained) {
            if retained != existing.samples {
                try write(CodexUsageWeeklyHistory(samples: retained))
            }
            return false
        }

        retained.append(sample)
        try write(CodexUsageWeeklyHistory(samples: retained))
        return true
    }

    private func shouldSkip(
        sample: CodexUsageWeeklyHistorySample,
        after retained: [CodexUsageWeeklyHistorySample]
    ) -> Bool {
        guard let last = retained.last(where: {
            $0.matchesResetWindow(
                resetsAt: sample.resetsAt,
                windowDurationMins: sample.windowDurationMins
            )
        }) else {
            return false
        }

        let timeDelta = sample.recordedAt - last.recordedAt
        guard timeDelta >= 0 else { return false }
        let valueDelta = abs(sample.remainingPercent - last.remainingPercent)
        return timeDelta < Self.minimumSampleIntervalSeconds &&
            valueDelta < Self.minimumRemainingPercentDelta
    }

    private func write(_ history: CodexUsageWeeklyHistory) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(history)
        try data.write(to: fileURL, options: [.atomic])
    }
}
