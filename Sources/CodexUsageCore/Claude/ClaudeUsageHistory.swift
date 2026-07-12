import Foundation

public struct ClaudeUsageHistory: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public static let empty = ClaudeUsageHistory(samples: [])

    public let schemaVersion: Int
    public let samples: [ClaudeUsageHistorySample]

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        samples: [ClaudeUsageHistorySample]
    ) {
        self.schemaVersion = schemaVersion
        self.samples = samples.sorted {
            if $0.recordedAt != $1.recordedAt { return $0.recordedAt < $1.recordedAt }
            if $0.kind != $1.kind { return $0.kind.rawValue < $1.kind.rawValue }
            return $0.resetsAt < $1.resetsAt
        }
    }

    public func samples(
        for kind: ClaudeUsageWindowKind,
        resetsAt: Int
    ) -> [ClaudeUsageHistorySample] {
        samples.filter { $0.kind == kind && $0.resetsAt == resetsAt }
    }

    public func resetWindows(for kind: ClaudeUsageWindowKind) -> [Int] {
        Array(Set(samples.lazy.filter { $0.kind == kind }.map(\.resetsAt))).sorted()
    }
}

public struct ClaudeUsageHistorySample: Codable, Equatable, Hashable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let kind: ClaudeUsageWindowKind
    public let recordedAt: Int
    public let usedPercent: Double
    public let resetsAt: Int

    public init?(
        schemaVersion: Int = Self.currentSchemaVersion,
        kind: ClaudeUsageWindowKind,
        recordedAt: Int,
        usedPercent: Double,
        resetsAt: Int
    ) {
        guard recordedAt > 0,
              usedPercent.isFinite,
              (0...100).contains(usedPercent),
              resetsAt > 0 else {
            return nil
        }
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.recordedAt = recordedAt
        self.usedPercent = usedPercent
        self.resetsAt = resetsAt
    }
}

public struct ClaudeUsageHistoryStore {
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
        fileURL.deletingLastPathComponent().appendingPathComponent("claude-usage-history.json")
    }

    public func read() throws -> ClaudeUsageHistory {
        guard fileManager.fileExists(atPath: fileURL.path) else { return .empty }
        return try decoder.decode(ClaudeUsageHistory.self, from: Data(contentsOf: fileURL))
    }

    @discardableResult
    public func append(_ newSamples: [ClaudeUsageHistorySample]) throws -> ClaudeUsageHistory {
        guard !newSamples.isEmpty else { return try read() }
        let existing = try read()
        var keyed = Dictionary(uniqueKeysWithValues: existing.samples.map { (Key($0), $0) })

        for sample in newSamples {
            let priorWindowMaximum = keyed.values.lazy
                .filter {
                    $0.kind == sample.kind &&
                        $0.resetsAt == sample.resetsAt &&
                        $0.recordedAt <= sample.recordedAt
                }
                .map(\.usedPercent)
                .max() ?? 0
            let monotonicUsedPercent = max(sample.usedPercent, priorWindowMaximum)
            let key = Key(sample)
            if let current = keyed[key] {
                keyed[key] = ClaudeUsageHistorySample(
                    kind: sample.kind,
                    recordedAt: sample.recordedAt,
                    usedPercent: max(current.usedPercent, monotonicUsedPercent),
                    resetsAt: sample.resetsAt
                )
            } else {
                keyed[key] = ClaudeUsageHistorySample(
                    kind: sample.kind,
                    recordedAt: sample.recordedAt,
                    usedPercent: monotonicUsedPercent,
                    resetsAt: sample.resetsAt
                )
            }
        }

        let retained = ClaudeUsageHistory(samples: Array(keyed.values)).samples
            .suffix(Self.maximumSampleCount)
        let history = ClaudeUsageHistory(samples: Array(retained))
        try write(history)
        return history
    }

    public func write(_ history: ClaudeUsageHistory) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try? fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        try dataWriter(try encoder.encode(history), fileURL, [.atomic])
        try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    private struct Key: Hashable {
        let kind: ClaudeUsageWindowKind
        let recordedAt: Int
        let resetsAt: Int

        init(_ sample: ClaudeUsageHistorySample) {
            self.kind = sample.kind
            self.recordedAt = sample.recordedAt
            self.resetsAt = sample.resetsAt
        }
    }
}

public enum ClaudeUsagePaceState: Equatable, Sendable {
    case projected
    case waitingForSamples
    case unavailable
}

public struct ClaudeUsagePaceProjection: Equatable, Sendable {
    public let state: ClaudeUsagePaceState
    public let kind: ClaudeUsageWindowKind
    public let currentUsedPercent: Double?
    public let usedPercentPerHour: Double?
    public let projectedFinalUsedPercent: Double?
    public let remainingSeconds: Int?
    public let sampleCount: Int
}

public struct ClaudeUsagePaceProjectionBuilder: Sendable {
    public init() {}

    public func projection(
        kind: ClaudeUsageWindowKind,
        snapshot: ClaudeStatusLineSnapshot,
        history: ClaudeUsageHistory
    ) -> ClaudeUsagePaceProjection {
        guard let window = snapshot.window(kind),
              let currentUsed = window.usedPercent,
              let resetsAt = window.resetsAt else {
            return ClaudeUsagePaceProjection(
                state: .unavailable,
                kind: kind,
                currentUsedPercent: nil,
                usedPercentPerHour: nil,
                projectedFinalUsedPercent: nil,
                remainingSeconds: nil,
                sampleCount: 0
            )
        }
        let samples = history.samples(for: kind, resetsAt: resetsAt)
            .filter { $0.recordedAt <= snapshot.observedAt }
        guard let previous = samples.last(where: { $0.recordedAt < snapshot.observedAt }),
              snapshot.observedAt > previous.recordedAt else {
            return ClaudeUsagePaceProjection(
                state: .waitingForSamples,
                kind: kind,
                currentUsedPercent: currentUsed,
                usedPercentPerHour: nil,
                projectedFinalUsedPercent: nil,
                remainingSeconds: max(0, resetsAt - snapshot.observedAt),
                sampleCount: max(1, samples.count)
            )
        }
        let elapsed = snapshot.observedAt - previous.recordedAt
        let ratePerSecond = max(0, currentUsed - previous.usedPercent) / Double(elapsed)
        let remaining = max(0, resetsAt - snapshot.observedAt)
        return ClaudeUsagePaceProjection(
            state: .projected,
            kind: kind,
            currentUsedPercent: currentUsed,
            usedPercentPerHour: ratePerSecond * 3_600,
            projectedFinalUsedPercent: min(100, currentUsed + ratePerSecond * Double(remaining)),
            remainingSeconds: remaining,
            sampleCount: samples.count
        )
    }
}
