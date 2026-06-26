import Foundation

public struct CodexUsageResetWindowHistory: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public static let empty = CodexUsageResetWindowHistory(records: [])

    public let schemaVersion: Int
    public let records: [CodexUsageResetWindowHistoryRecord]

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        records: [CodexUsageResetWindowHistoryRecord]
    ) {
        self.schemaVersion = schemaVersion
        self.records = records.sorted {
            if $0.resetsAt != $1.resetsAt {
                return $0.resetsAt < $1.resetsAt
            }
            if $0.windowDurationMins != $1.windowDurationMins {
                return $0.windowDurationMins < $1.windowDurationMins
            }
            return $0.limitId < $1.limitId
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ??
            Self.currentSchemaVersion
        let records = try container.decodeIfPresent([CodexUsageResetWindowHistoryRecord].self, forKey: .records) ?? []
        self.init(schemaVersion: schemaVersion, records: records)
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case records
    }
}

public struct CodexUsageResetWindowHistoryKey: Codable, Equatable, Hashable, Sendable {
    public let limitId: String
    public let windowDurationMins: Int
    public let resetsAt: Int

    public init(limitId: String, windowDurationMins: Int, resetsAt: Int) {
        self.limitId = limitId
        self.windowDurationMins = windowDurationMins
        self.resetsAt = resetsAt
    }
}

public enum CodexUsageResetWindowHistorySource: String, Codable, Equatable, Sendable {
    case liveCache = "live-cache"
    case backfill
    case importedSummary = "imported-summary"
}

public struct CodexUsageResetWindowBackfillSummary: Codable, Equatable, Sendable {
    public let generatedAt: Int
    public let limitId: String
    public let windowDurationMins: Int
    public let resetsAt: Int
    public let dailyEndSamples: [CodexUsageResetWindowDailySample]
    public let finalUsedPercent: Double
    public let finalRemainingPercent: Double
    public let sampleCount: Int

    public init(
        generatedAt: Int,
        limitId: String,
        windowDurationMins: Int,
        resetsAt: Int,
        dailyEndSamples: [CodexUsageResetWindowDailySample],
        finalUsedPercent: Double,
        finalRemainingPercent: Double,
        sampleCount: Int
    ) {
        self.generatedAt = generatedAt
        self.limitId = limitId
        self.windowDurationMins = windowDurationMins
        self.resetsAt = resetsAt
        self.dailyEndSamples = dailyEndSamples
        self.finalUsedPercent = Self.clampedPercent(finalUsedPercent)
        self.finalRemainingPercent = Self.clampedPercent(finalRemainingPercent)
        self.sampleCount = max(sampleCount, 0)
    }

    private static func clampedPercent(_ value: Double) -> Double {
        min(max(value, 0), 100)
    }
}

public struct CodexUsageResetWindowBackfillBuilder: Sendable {
    private static let resetTimestampToleranceSeconds = CodexUsageWeeklyHistorySample
        .resetWindowTimestampToleranceSeconds
    private static let weeklyWindowDurationMins = 10_080

    public init() {}

    public func record(
        from summary: CodexUsageResetWindowBackfillSummary
    ) -> CodexUsageResetWindowHistoryRecord {
        CodexUsageResetWindowHistoryRecord(
            generatedAt: summary.generatedAt,
            limitId: summary.limitId,
            windowDurationMins: summary.windowDurationMins,
            resetsAt: summary.resetsAt,
            dailyEndSamples: summary.dailyEndSamples,
            finalUsedPercent: summary.finalUsedPercent,
            finalRemainingPercent: summary.finalRemainingPercent,
            sampleCount: summary.sampleCount,
            source: .backfill
        )
    }

    public func summaries(
        from weeklyHistory: CodexUsageWeeklyHistory,
        completedAtOrBefore referenceTimestamp: Int,
        excludingCurrentResetsAt currentResetsAt: Int? = nil,
        limitId: String = "codex"
    ) -> [CodexUsageResetWindowBackfillSummary] {
        groupedCompletedWeeklySamples(
            from: weeklyHistory,
            completedAtOrBefore: referenceTimestamp,
            excludingCurrentResetsAt: currentResetsAt
        )
        .compactMap { group in
            summary(from: group, limitId: limitId)
        }
    }

    private func groupedCompletedWeeklySamples(
        from weeklyHistory: CodexUsageWeeklyHistory,
        completedAtOrBefore referenceTimestamp: Int,
        excludingCurrentResetsAt currentResetsAt: Int?
    ) -> [[CodexUsageWeeklyHistorySample]] {
        let candidates = weeklyHistory.samples
            .filter { sample in
                sample.windowDurationMins == Self.weeklyWindowDurationMins &&
                    sample.resetsAt <= referenceTimestamp &&
                    !Self.isCurrentReset(sample.resetsAt, currentResetsAt: currentResetsAt)
            }
            .sorted {
                if $0.windowDurationMins != $1.windowDurationMins {
                    return $0.windowDurationMins < $1.windowDurationMins
                }
                if $0.resetsAt != $1.resetsAt {
                    return $0.resetsAt < $1.resetsAt
                }
                return $0.recordedAt < $1.recordedAt
            }

        return candidates.reduce(into: []) { groups, sample in
            guard let lastGroup = groups.last,
                  let representative = lastGroup.first,
                  representative.windowDurationMins == sample.windowDurationMins,
                  abs(representative.resetsAt - sample.resetsAt) <= Self.resetTimestampToleranceSeconds
            else {
                groups.append([sample])
                return
            }

            groups[groups.count - 1].append(sample)
        }
    }

    private func summary(
        from group: [CodexUsageWeeklyHistorySample],
        limitId: String
    ) -> CodexUsageResetWindowBackfillSummary? {
        guard let first = group.first else { return nil }

        let resetsAt = canonicalResetsAt(in: group)
        let resetStartAt = resetsAt - first.windowDurationMins * 60
        let windowSamples = group
            .filter { $0.recordedAt >= resetStartAt && $0.recordedAt <= resetsAt }
            .sorted { $0.recordedAt < $1.recordedAt }
        guard let finalSample = windowSamples.last else { return nil }

        let daySeconds = max(first.windowDurationMins * 60 / 7, 1)
        let dailySamples = (1...7).compactMap { dayIndex -> CodexUsageResetWindowDailySample? in
            let dayStartAt = resetStartAt + (dayIndex - 1) * daySeconds
            let dayEndAt = resetStartAt + dayIndex * daySeconds
            guard let sample = windowSamples.last(where: {
                $0.recordedAt >= dayStartAt && $0.recordedAt <= dayEndAt
            }) else {
                return nil
            }

            return CodexUsageResetWindowDailySample(
                dayIndex: dayIndex,
                recordedAt: sample.recordedAt,
                usedPercent: sample.usedPercent,
                remainingPercent: sample.remainingPercent
            )
        }

        return CodexUsageResetWindowBackfillSummary(
            generatedAt: finalSample.recordedAt,
            limitId: limitId,
            windowDurationMins: first.windowDurationMins,
            resetsAt: resetsAt,
            dailyEndSamples: dailySamples,
            finalUsedPercent: finalSample.usedPercent,
            finalRemainingPercent: finalSample.remainingPercent,
            sampleCount: windowSamples.count
        )
    }

    private func canonicalResetsAt(in group: [CodexUsageWeeklyHistorySample]) -> Int {
        let counts = Dictionary(grouping: group, by: \.resetsAt)
            .mapValues(\.count)
        return counts.sorted {
            if $0.value != $1.value {
                return $0.value > $1.value
            }
            return $0.key < $1.key
        }.first?.key ?? group[0].resetsAt
    }

    private static func isCurrentReset(_ resetsAt: Int, currentResetsAt: Int?) -> Bool {
        guard let currentResetsAt else { return false }
        return abs(resetsAt - currentResetsAt) <= resetTimestampToleranceSeconds
    }
}

public struct CodexUsageResetWindowDailySample: Codable, Equatable, Sendable {
    public let dayIndex: Int
    public let recordedAt: Int
    public let usedPercent: Double
    public let remainingPercent: Double

    public init(
        dayIndex: Int,
        recordedAt: Int,
        usedPercent: Double,
        remainingPercent: Double
    ) {
        self.dayIndex = min(max(dayIndex, 1), 7)
        self.recordedAt = recordedAt
        self.usedPercent = Self.clampedPercent(usedPercent)
        self.remainingPercent = Self.clampedPercent(remainingPercent)
    }

    private static func clampedPercent(_ value: Double) -> Double {
        min(max(value, 0), 100)
    }
}

public struct CodexUsageResetWindowHistoryRecord: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let generatedAt: Int
    public let limitId: String
    public let windowDurationMins: Int
    public let resetStartAt: Int
    public let resetsAt: Int
    public let dailyEndSamples: [CodexUsageResetWindowDailySample]
    public let finalUsedPercent: Double
    public let finalRemainingPercent: Double
    public let sampleCount: Int
    public let source: CodexUsageResetWindowHistorySource

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        generatedAt: Int,
        limitId: String,
        windowDurationMins: Int,
        resetsAt: Int,
        dailyEndSamples: [CodexUsageResetWindowDailySample],
        finalUsedPercent: Double,
        finalRemainingPercent: Double,
        sampleCount: Int,
        source: CodexUsageResetWindowHistorySource
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.limitId = limitId
        self.windowDurationMins = windowDurationMins
        self.resetStartAt = resetsAt - windowDurationMins * 60
        self.resetsAt = resetsAt
        self.dailyEndSamples = dailyEndSamples.sorted { $0.dayIndex < $1.dayIndex }
        self.finalUsedPercent = Self.clampedPercent(finalUsedPercent)
        self.finalRemainingPercent = Self.clampedPercent(finalRemainingPercent)
        self.sampleCount = max(sampleCount, 0)
        self.source = source
    }

    public init(
        weeklySample sample: CodexUsageWeeklyHistorySample,
        generatedAt: Int,
        limitId: String = "codex",
        source: CodexUsageResetWindowHistorySource = .liveCache,
        previousRecord: CodexUsageResetWindowHistoryRecord? = nil
    ) {
        let marker = CodexUsageResetWindowDailySample(
            dayIndex: Self.dayIndex(
                recordedAt: sample.recordedAt,
                resetsAt: sample.resetsAt,
                windowDurationMins: sample.windowDurationMins
            ),
            recordedAt: sample.recordedAt,
            usedPercent: sample.usedPercent,
            remainingPercent: sample.remainingPercent
        )
        let previousSamples = previousRecord?.dailyEndSamples.filter { $0.dayIndex != marker.dayIndex } ?? []

        self.init(
            generatedAt: generatedAt,
            limitId: limitId,
            windowDurationMins: sample.windowDurationMins,
            resetsAt: sample.resetsAt,
            dailyEndSamples: previousSamples + [marker],
            finalUsedPercent: sample.usedPercent,
            finalRemainingPercent: sample.remainingPercent,
            sampleCount: (previousRecord?.sampleCount ?? 0) + 1,
            source: source
        )
    }

    public var key: CodexUsageResetWindowHistoryKey {
        CodexUsageResetWindowHistoryKey(
            limitId: limitId,
            windowDurationMins: windowDurationMins,
            resetsAt: resetsAt
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            schemaVersion: try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ??
                Self.currentSchemaVersion,
            generatedAt: try container.decode(Int.self, forKey: .generatedAt),
            limitId: try container.decode(String.self, forKey: .limitId),
            windowDurationMins: try container.decode(Int.self, forKey: .windowDurationMins),
            resetsAt: try container.decode(Int.self, forKey: .resetsAt),
            dailyEndSamples: try container.decodeIfPresent(
                [CodexUsageResetWindowDailySample].self,
                forKey: .dailyEndSamples
            ) ?? [],
            finalUsedPercent: try container.decode(Double.self, forKey: .finalUsedPercent),
            finalRemainingPercent: try container.decode(Double.self, forKey: .finalRemainingPercent),
            sampleCount: try container.decodeIfPresent(Int.self, forKey: .sampleCount) ?? 0,
            source: try container.decodeIfPresent(
                CodexUsageResetWindowHistorySource.self,
                forKey: .source
            ) ?? .liveCache
        )
    }

    func migratedToCurrentSchema() -> CodexUsageResetWindowHistoryRecord {
        guard schemaVersion != Self.currentSchemaVersion else { return self }
        return CodexUsageResetWindowHistoryRecord(
            generatedAt: generatedAt,
            limitId: limitId,
            windowDurationMins: windowDurationMins,
            resetsAt: resetsAt,
            dailyEndSamples: dailyEndSamples,
            finalUsedPercent: finalUsedPercent,
            finalRemainingPercent: finalRemainingPercent,
            sampleCount: sampleCount,
            source: source
        )
    }

    private static func clampedPercent(_ value: Double) -> Double {
        min(max(value, 0), 100)
    }

    private static func dayIndex(
        recordedAt: Int,
        resetsAt: Int,
        windowDurationMins: Int
    ) -> Int {
        let durationSeconds = max(windowDurationMins * 60, 1)
        let resetStartAt = resetsAt - durationSeconds
        let elapsed = min(max(recordedAt - resetStartAt, 0), max(durationSeconds - 1, 0))
        let daySeconds = max(durationSeconds / 7, 1)
        return min(max(elapsed / daySeconds + 1, 1), 7)
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case generatedAt
        case limitId
        case windowDurationMins
        case resetStartAt
        case resetsAt
        case dailyEndSamples
        case finalUsedPercent
        case finalRemainingPercent
        case sampleCount
        case source
    }
}

public struct CodexUsageResetWindowHistoryStore {
    public static let fileName = "usage-reset-window-history.json"
    public static let completedWindowRetentionCount = 12

    private static var retainedWindowCount: Int {
        completedWindowRetentionCount + 1
    }

    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        fileURL: URL = Self.defaultFileURL(),
        fileManager: FileManager = .default
    ) {
        self.fileURL = fileURL
        self.fileManager = fileManager
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

    public func read() throws -> CodexUsageResetWindowHistory {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return .empty
        }
        let data = try Data(contentsOf: fileURL)
        let decoded = try decoder.decode(CodexUsageResetWindowHistory.self, from: data)
        return CodexUsageResetWindowHistory(
            records: decoded.records.map { $0.migratedToCurrentSchema() }
        )
    }

    @discardableResult
    public func append(_ record: CodexUsageResetWindowHistoryRecord) throws -> Bool {
        let existing = try read()
        let existingRecord = existing.records.first { $0.key == record.key }
        let candidate: CodexUsageResetWindowHistoryRecord
        if let existingRecord, existingRecord.generatedAt > record.generatedAt {
            candidate = existingRecord
        } else {
            candidate = record
        }

        let records = existing.records.filter { $0.key != candidate.key } + [candidate]
        let retained = Self.retained(records)
        let next = CodexUsageResetWindowHistory(records: retained)
        guard next != existing else {
            return false
        }

        try write(next)
        return true
    }

    @discardableResult
    public func append(
        sample: CodexUsageWeeklyHistorySample,
        generatedAt: Int,
        limitId: String = "codex"
    ) throws -> Bool {
        let key = CodexUsageResetWindowHistoryKey(
            limitId: limitId,
            windowDurationMins: sample.windowDurationMins,
            resetsAt: sample.resetsAt
        )
        let previousRecord = try read().records.first { $0.key == key }
        let record = CodexUsageResetWindowHistoryRecord(
            weeklySample: sample,
            generatedAt: generatedAt,
            limitId: limitId,
            previousRecord: previousRecord
        )
        return try append(record)
    }

    @discardableResult
    public func appendBackfillSummaries(
        _ summaries: [CodexUsageResetWindowBackfillSummary]
    ) throws -> Int {
        let builder = CodexUsageResetWindowBackfillBuilder()
        var appendedCount = 0
        for summary in summaries where try append(builder.record(from: summary)) {
            appendedCount += 1
        }
        return appendedCount
    }

    private func write(_ history: CodexUsageResetWindowHistory) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(history)
        try data.write(to: fileURL, options: [.atomic])
    }

    private static func retained(
        _ records: [CodexUsageResetWindowHistoryRecord]
    ) -> [CodexUsageResetWindowHistoryRecord] {
        let groups = Dictionary(grouping: records) {
            RetentionGroupKey(limitId: $0.limitId, windowDurationMins: $0.windowDurationMins)
        }

        return groups.values
            .flatMap { group in
                group.sorted { $0.resetsAt > $1.resetsAt }.prefix(retainedWindowCount)
            }
            .sorted {
                if $0.resetsAt != $1.resetsAt {
                    return $0.resetsAt < $1.resetsAt
                }
                if $0.windowDurationMins != $1.windowDurationMins {
                    return $0.windowDurationMins < $1.windowDurationMins
                }
                return $0.limitId < $1.limitId
            }
    }

    private struct RetentionGroupKey: Hashable {
        let limitId: String
        let windowDurationMins: Int
    }
}
