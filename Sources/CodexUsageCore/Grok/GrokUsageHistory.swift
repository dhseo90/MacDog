import Foundation

public struct GrokUsageHistory: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public static let empty = GrokUsageHistory(samples: [])

    public let schemaVersion: Int
    public let samples: [GrokUsageHistorySample]

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        samples: [GrokUsageHistorySample]
    ) {
        self.schemaVersion = schemaVersion
        self.samples = samples.sorted {
            if $0.recordedAt != $1.recordedAt { return $0.recordedAt < $1.recordedAt }
            return ($0.resetsAt ?? 0) < ($1.resetsAt ?? 0)
        }
    }

    public func samples(resetsAt: Int?) -> [GrokUsageHistorySample] {
        samples.filter { $0.resetsAt == resetsAt }
    }
}

public struct GrokUsageHistorySample: Codable, Equatable, Hashable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let recordedAt: Int
    public let usedPercent: Double
    public let remainingPercent: Double
    public let resetsAt: Int?

    public init?(
        schemaVersion: Int = Self.currentSchemaVersion,
        recordedAt: Int,
        usedPercent: Double,
        remainingPercent: Double? = nil,
        resetsAt: Int?
    ) {
        guard recordedAt > 0,
              usedPercent.isFinite,
              (0...100).contains(usedPercent) else {
            return nil
        }
        let remaining = remainingPercent ?? (100 - usedPercent)
        guard remaining.isFinite else { return nil }
        self.schemaVersion = schemaVersion
        self.recordedAt = recordedAt
        self.usedPercent = usedPercent
        self.remainingPercent = 100 - usedPercent
        self.resetsAt = resetsAt.flatMap { $0 > 0 ? $0 : nil }
    }
}

public struct GrokUsageHistoryStore {
    public static let maximumSampleCount = 4_096

    public let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let dataWriter: (Data, URL, Data.WritingOptions) throws -> Void

    public init(
        fileURL: URL,
        fileManager: FileManager = .default,
        dataWriter: @escaping (Data, URL, Data.WritingOptions) throws -> Void = {
            try $0.write(to: $1, options: $2)
        }
    ) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
        self.dataWriter = dataWriter
    }

    public static func defaultFileURL(adjacentToCacheFileURL fileURL: URL) -> URL {
        fileURL.deletingLastPathComponent().appendingPathComponent("grok-usage-history.json")
    }

    public func read() throws -> GrokUsageHistory {
        guard fileManager.fileExists(atPath: fileURL.path) else { return .empty }
        return try decoder.decode(GrokUsageHistory.self, from: Data(contentsOf: fileURL))
    }

    @discardableResult
    public func append(_ newSamples: [GrokUsageHistorySample]) throws -> GrokUsageHistory {
        guard !newSamples.isEmpty else { return try read() }
        let existing = try read()
        var keyed = Dictionary(uniqueKeysWithValues: existing.samples.map { (Key($0), $0) })

        for sample in newSamples {
            let priorWindowMaximum = keyed.values.lazy
                .filter {
                    $0.resetsAt == sample.resetsAt &&
                        $0.recordedAt <= sample.recordedAt
                }
                .map(\.usedPercent)
                .max() ?? 0
            let monotonicUsedPercent = max(sample.usedPercent, priorWindowMaximum)
            let key = Key(sample)
            if let current = keyed[key] {
                keyed[key] = GrokUsageHistorySample(
                    recordedAt: sample.recordedAt,
                    usedPercent: max(current.usedPercent, monotonicUsedPercent),
                    resetsAt: sample.resetsAt
                )
            } else {
                keyed[key] = GrokUsageHistorySample(
                    recordedAt: sample.recordedAt,
                    usedPercent: monotonicUsedPercent,
                    resetsAt: sample.resetsAt
                )
            }
        }

        let retained = GrokUsageHistory(samples: Array(keyed.values)).samples
            .suffix(Self.maximumSampleCount)
        let history = GrokUsageHistory(samples: Array(retained))
        try write(history)
        return history
    }

    public func write(_ history: GrokUsageHistory) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        try dataWriter(try encoder.encode(history), fileURL, [.atomic])
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    private struct Key: Hashable {
        let recordedAt: Int
        let resetsAt: Int?

        init(_ sample: GrokUsageHistorySample) {
            self.recordedAt = sample.recordedAt
            self.resetsAt = sample.resetsAt
        }
    }
}
