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

    public var key: CodexUsageResetWindowHistoryKey {
        CodexUsageResetWindowHistoryKey(
            limitId: limitId,
            windowDurationMins: windowDurationMins,
            resetsAt: resetsAt
        )
    }

    private static func clampedPercent(_ value: Double) -> Double {
        min(max(value, 0), 100)
    }
}
