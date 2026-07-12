import Foundation

public struct CodexUsageFiveHourHistory: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public static let empty = CodexUsageFiveHourHistory(samples: [])

    public let schemaVersion: Int
    public let samples: [CodexUsageFiveHourHistorySample]

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        samples: [CodexUsageFiveHourHistorySample]
    ) {
        self.schemaVersion = schemaVersion
        self.samples = samples.sorted { lhs, rhs in
            if lhs.recordedAt != rhs.recordedAt {
                return lhs.recordedAt < rhs.recordedAt
            }
            if lhs.resetsAt != rhs.resetsAt {
                return lhs.resetsAt < rhs.resetsAt
            }
            return lhs.usedPercent < rhs.usedPercent
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let samples = try container.decodeIfPresent(
            [CodexUsageFiveHourHistorySample].self,
            forKey: .samples
        ) ?? []
        self.init(samples: samples)
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case samples
    }
}

public struct CodexUsageFiveHourHistorySample: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public static let expectedWindowDurationMins = 300
    public static let logicalWindowTimestampToleranceSeconds = 5 * 60
    public let schemaVersion: Int
    public let recordedAt: Int
    public let windowDurationMins: Int
    public let usedPercent: Double
    public let resetsAt: Int

    public init?(
        schemaVersion: Int = Self.currentSchemaVersion,
        recordedAt: Int,
        windowDurationMins: Int,
        usedPercent: Double,
        resetsAt: Int
    ) {
        guard windowDurationMins == Self.expectedWindowDurationMins,
              usedPercent.isFinite
        else {
            return nil
        }

        self.schemaVersion = schemaVersion
        self.recordedAt = recordedAt
        self.windowDurationMins = windowDurationMins
        self.usedPercent = min(max(usedPercent, 0), 100)
        self.resetsAt = resetsAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: LegacyCodingKeys.self)
        let recordedAt = try container.decode(Int.self, forKey: .recordedAt)
        let windowDurationMins = try container.decode(Int.self, forKey: .windowDurationMins)
        let usedPercent = try container.decode(Double.self, forKey: .usedPercent)
        let resetsAt = try container.decode(Int.self, forKey: .resetsAt)
        _ = try container.decodeIfPresent(String.self, forKey: .planEpochID)

        guard let migrated = Self.init(
            recordedAt: recordedAt,
            windowDurationMins: windowDurationMins,
            usedPercent: usedPercent,
            resetsAt: resetsAt
        ) else {
            throw DecodingError.dataCorruptedError(
                forKey: .windowDurationMins,
                in: container,
                debugDescription: "Five-hour history samples require a 300-minute window and finite usage."
            )
        }
        self = migrated
    }

    public func matchesLogicalWindow(_ other: Self) -> Bool {
        guard windowDurationMins == other.windowDurationMins else {
            return false
        }
        return abs(resetsAt - other.resetsAt) <= Self.logicalWindowTimestampToleranceSeconds
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case recordedAt
        case windowDurationMins
        case usedPercent
        case resetsAt
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case schemaVersion
        case recordedAt
        case windowDurationMins
        case usedPercent
        case resetsAt
        case planEpochID
    }
}

public struct CodexUsageFiveHourHistoryStore {
    public static let fileName = "usage-five-hour-history.json"
    public static let minimumSampleIntervalSeconds = 5 * 60
    public static let minimumUsedPercentDelta = 0.25
    public static let defaultRetentionSeconds = 13 * 7 * 24 * 60 * 60

    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let dataWriter: (Data, URL, Data.WritingOptions) throws -> Void

    public init(
        fileURL: URL = Self.defaultFileURL(),
        fileManager: FileManager = .default
    ) {
        self.init(
            fileURL: fileURL,
            fileManager: fileManager,
            dataWriter: { data, destination, options in
                try data.write(to: destination, options: options)
            }
        )
    }

    init(
        fileURL: URL,
        fileManager: FileManager = .default,
        dataWriter: @escaping (Data, URL, Data.WritingOptions) throws -> Void
    ) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
        self.dataWriter = dataWriter
    }

    public static func defaultFileURL() -> URL {
        CodexUsageCacheStore.defaultApplicationSupportDirectoryURL()
            .appendingPathComponent(fileName)
    }

    public static func defaultFileURL(adjacentToCacheFileURL cacheFileURL: URL) -> URL {
        cacheFileURL.deletingLastPathComponent().appendingPathComponent(fileName)
    }

    public func read() throws -> CodexUsageFiveHourHistory {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return .empty
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(CodexUsageFiveHourHistory.self, from: data)
    }

    @discardableResult
    public func append(_ sample: CodexUsageFiveHourHistorySample) throws -> Bool {
        let existing = try read()
        let retentionAnchor = max(
            sample.recordedAt,
            existing.samples.map(\.recordedAt).max() ?? sample.recordedAt
        )
        var retained = existing.samples.filter {
            retentionAnchor - $0.recordedAt <= Self.defaultRetentionSeconds
        }

        guard retentionAnchor - sample.recordedAt <= Self.defaultRetentionSeconds else {
            if retained != existing.samples {
                try write(CodexUsageFiveHourHistory(samples: retained))
            }
            return false
        }

        if retained.contains(sample) {
            if retained != existing.samples {
                try write(CodexUsageFiveHourHistory(samples: retained))
            }
            return false
        }

        retained.removeAll {
            $0.recordedAt == sample.recordedAt && $0.matchesLogicalWindow(sample)
        }

        if shouldSkip(sample, after: retained) {
            if retained != existing.samples {
                try write(CodexUsageFiveHourHistory(samples: retained))
            }
            return false
        }

        retained.append(sample)
        try write(CodexUsageFiveHourHistory(samples: retained))
        return true
    }

    private func shouldSkip(
        _ sample: CodexUsageFiveHourHistorySample,
        after retained: [CodexUsageFiveHourHistorySample]
    ) -> Bool {
        guard let latest = retained.last(where: { $0.matchesLogicalWindow(sample) }) else {
            return false
        }
        let timeDelta = sample.recordedAt - latest.recordedAt
        guard timeDelta >= 0 else { return false }
        return timeDelta < Self.minimumSampleIntervalSeconds &&
            abs(sample.usedPercent - latest.usedPercent) < Self.minimumUsedPercentDelta
    }

    private func write(_ history: CodexUsageFiveHourHistory) throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try dataWriter(encoder.encode(history), fileURL, [.atomic])
    }
}
