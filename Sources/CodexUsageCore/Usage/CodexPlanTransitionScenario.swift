import Foundation

public enum CodexPlanTransitionConfigurationError: Error, Equatable, LocalizedError {
    case emptyPlanLabel
    case invalidRelativeCapacity
    case invalidReservePercent
    case invalidTransitionTimestamp
    case emptyEpochID

    public var errorDescription: String? {
        switch self {
        case .emptyPlanLabel:
            "플랜 label을 입력해 주세요."
        case .invalidRelativeCapacity:
            "목표 상대 용량은 0보다 커야 합니다."
        case .invalidReservePercent:
            "reserve는 0%에서 100% 사이여야 합니다."
        case .invalidTransitionTimestamp:
            "전환 시각이 올바르지 않습니다."
        case .emptyEpochID:
            "플랜 epoch ID가 비어 있습니다."
        }
    }
}

public struct CodexPlanTransitionConfiguration: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let currentPlanLabel: String
    public let targetPlanLabel: String
    public let targetRelativeCapacity: Double
    public let reservePercent: Double
    public let plannedTransitionAt: Int?
    public let confirmedTransitionAt: Int?
    public let currentPlanEpochID: String
    public let targetPlanEpochID: String

    public init(
        schemaVersion: Int = Self.currentSchemaVersion,
        currentPlanLabel: String,
        targetPlanLabel: String,
        targetRelativeCapacity: Double,
        reservePercent: Double,
        plannedTransitionAt: Int? = nil,
        confirmedTransitionAt: Int? = nil,
        currentPlanEpochID: String,
        targetPlanEpochID: String
    ) throws {
        let currentPlanLabel = currentPlanLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetPlanLabel = targetPlanLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentPlanEpochID = currentPlanEpochID.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetPlanEpochID = targetPlanEpochID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentPlanLabel.isEmpty, !targetPlanLabel.isEmpty else {
            throw CodexPlanTransitionConfigurationError.emptyPlanLabel
        }
        guard targetRelativeCapacity.isFinite, targetRelativeCapacity > 0 else {
            throw CodexPlanTransitionConfigurationError.invalidRelativeCapacity
        }
        guard reservePercent.isFinite, (0...100).contains(reservePercent) else {
            throw CodexPlanTransitionConfigurationError.invalidReservePercent
        }
        guard plannedTransitionAt.map({ $0 > 0 }) ?? true,
              confirmedTransitionAt.map({ $0 > 0 }) ?? true
        else {
            throw CodexPlanTransitionConfigurationError.invalidTransitionTimestamp
        }
        guard !currentPlanEpochID.isEmpty, !targetPlanEpochID.isEmpty else {
            throw CodexPlanTransitionConfigurationError.emptyEpochID
        }

        self.schemaVersion = schemaVersion
        self.currentPlanLabel = currentPlanLabel
        self.targetPlanLabel = targetPlanLabel
        self.targetRelativeCapacity = targetRelativeCapacity
        self.reservePercent = reservePercent
        self.plannedTransitionAt = plannedTransitionAt
        self.confirmedTransitionAt = confirmedTransitionAt
        self.currentPlanEpochID = currentPlanEpochID
        self.targetPlanEpochID = targetPlanEpochID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            currentPlanLabel: container.decode(String.self, forKey: .currentPlanLabel),
            targetPlanLabel: container.decode(String.self, forKey: .targetPlanLabel),
            targetRelativeCapacity: container.decode(Double.self, forKey: .targetRelativeCapacity),
            reservePercent: container.decode(Double.self, forKey: .reservePercent),
            plannedTransitionAt: container.decodeIfPresent(Int.self, forKey: .plannedTransitionAt),
            confirmedTransitionAt: container.decodeIfPresent(Int.self, forKey: .confirmedTransitionAt),
            currentPlanEpochID: container.decode(String.self, forKey: .currentPlanEpochID),
            targetPlanEpochID: container.decode(String.self, forKey: .targetPlanEpochID)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(currentPlanLabel, forKey: .currentPlanLabel)
        try container.encode(targetPlanLabel, forKey: .targetPlanLabel)
        try container.encode(targetRelativeCapacity, forKey: .targetRelativeCapacity)
        try container.encode(reservePercent, forKey: .reservePercent)
        try container.encode(plannedTransitionAt, forKey: .plannedTransitionAt)
        try container.encode(confirmedTransitionAt, forKey: .confirmedTransitionAt)
        try container.encode(currentPlanEpochID, forKey: .currentPlanEpochID)
        try container.encode(targetPlanEpochID, forKey: .targetPlanEpochID)
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case currentPlanLabel
        case targetPlanLabel
        case targetRelativeCapacity
        case reservePercent
        case plannedTransitionAt
        case confirmedTransitionAt
        case currentPlanEpochID
        case targetPlanEpochID
    }
}

public struct CodexPlanTransitionConfigurationStore {
    public static let fileName = "usage-plan-transition.json"

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

    public func read() throws -> CodexPlanTransitionConfiguration {
        try decoder.decode(
            CodexPlanTransitionConfiguration.self,
            from: Data(contentsOf: fileURL)
        )
    }

    public func write(_ configuration: CodexPlanTransitionConfiguration) throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(configuration).write(to: fileURL, options: [.atomic])
    }
}

public struct CodexPlanEpoch: Codable, Equatable, Sendable {
    public let id: String
    public let planLabel: String
    public let startsAt: Int?
    public let endsAt: Int?
    public let isActive: Bool

    public init(
        id: String,
        planLabel: String,
        startsAt: Int?,
        endsAt: Int?,
        isActive: Bool = true
    ) {
        self.id = id
        self.planLabel = planLabel
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.isActive = isActive
    }

    public func contains(_ timestamp: Int) -> Bool {
        guard isActive else { return false }
        if let startsAt, timestamp < startsAt { return false }
        if let endsAt, timestamp >= endsAt { return false }
        return true
    }
}

public struct CodexPlanTransitionEpochs: Equatable, Sendable {
    public let current: CodexPlanEpoch
    public let target: CodexPlanEpoch

    public init(configuration: CodexPlanTransitionConfiguration) {
        let boundary = configuration.confirmedTransitionAt
        self.current = CodexPlanEpoch(
            id: configuration.currentPlanEpochID,
            planLabel: configuration.currentPlanLabel,
            startsAt: nil,
            endsAt: boundary,
            isActive: true
        )
        self.target = CodexPlanEpoch(
            id: configuration.targetPlanEpochID,
            planLabel: configuration.targetPlanLabel,
            startsAt: boundary,
            endsAt: nil,
            isActive: boundary != nil
        )
    }

    public func planEpochID(at timestamp: Int) -> String {
        target.contains(timestamp) && target.startsAt != nil ? target.id : current.id
    }
}

public enum CodexPlanTransitionWindow: String, Codable, Equatable, Sendable {
    case fiveHour = "five-hour"
    case weekly
}

public struct CodexPlanTransitionObservation: Codable, Equatable, Sendable {
    public let window: CodexPlanTransitionWindow
    public let windowStartedAt: Int
    public let windowEndedAt: Int
    public let recordedAt: Int
    public let planEpochID: String
    public let usedPercent: Double

    public init(
        window: CodexPlanTransitionWindow,
        windowStartedAt: Int,
        windowEndedAt: Int,
        recordedAt: Int,
        planEpochID: String,
        usedPercent: Double
    ) throws {
        guard windowStartedAt < windowEndedAt,
              recordedAt >= windowStartedAt,
              !planEpochID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              usedPercent.isFinite,
              (0...100).contains(usedPercent)
        else {
            throw CodexPlanTransitionConfigurationError.invalidTransitionTimestamp
        }
        self.window = window
        self.windowStartedAt = windowStartedAt
        self.windowEndedAt = windowEndedAt
        self.recordedAt = recordedAt
        self.planEpochID = planEpochID
        self.usedPercent = usedPercent
    }

    public func isFullyContained(in epoch: CodexPlanEpoch) -> Bool {
        planEpochID == epoch.id &&
            epoch.contains(windowStartedAt) &&
            epoch.contains(windowEndedAt - 1)
    }
}

public enum CodexPlanTransitionObservationStatus: String, Codable, Equatable, Sendable {
    case insufficient
    case sufficient
}

public struct CodexPlanTransitionProjection: Equatable, Sendable {
    public let observationStatus: CodexPlanTransitionObservationStatus
    public let observationCount: Int
    public let observationDurationSeconds: Int
    public let observedP50Percent: Double?
    public let observedP90Percent: Double?
    public let observedMaximumPercent: Double?
    public let projectedP50Percent: Double?
    public let projectedP90Percent: Double?
    public let projectedMaximumPercent: Double?
    public let reserveShortfallWindowCount: Int
    public let limitExceededWindowCount: Int
}

public enum CodexPlanTransitionStatus: Equatable, Sendable {
    case notScheduled
    case planned(at: Int)
    case observing(until: Int)
    case completed(observedThrough: Int)
    case awaitingObservations(since: Int)
}

public struct CodexPlanTransitionScenario: Equatable, Sendable {
    public let basisLabel: String
    public let observationStatus: CodexPlanTransitionObservationStatus
    public let transitionStatus: CodexPlanTransitionStatus
    public let fiveHour: CodexPlanTransitionProjection
    public let weekly: CodexPlanTransitionProjection
    public let targetFiveHour: CodexPlanTransitionProjection
    public let targetWeekly: CodexPlanTransitionProjection
    public let fiveHourP90DeltaPercent: Double?
}

public struct CodexPlanTransitionScenarioBuilder: Sendable {
    public static let defaultMinimumObservationCount = 6
    public static let defaultMinimumObservationDurationSeconds = 24 * 60 * 60

    public let minimumObservationCount: Int
    public let minimumObservationDurationSeconds: Int

    public init(
        minimumObservationCount: Int = Self.defaultMinimumObservationCount,
        minimumObservationDurationSeconds: Int = Self.defaultMinimumObservationDurationSeconds
    ) {
        self.minimumObservationCount = max(minimumObservationCount, 1)
        self.minimumObservationDurationSeconds = max(minimumObservationDurationSeconds, 0)
    }

    public func scenario(
        configuration: CodexPlanTransitionConfiguration,
        observations: [CodexPlanTransitionObservation],
        now: Int
    ) -> CodexPlanTransitionScenario {
        let epochs = CodexPlanTransitionEpochs(configuration: configuration)
        let currentEpochObservations = observations.filter {
            $0.windowEndedAt <= now && $0.isFullyContained(in: epochs.current)
        }
        let targetObservationCutoff = configuration.confirmedTransitionAt.map {
            min(now, $0 + 7 * 24 * 60 * 60)
        } ?? now
        let targetEpochObservations = observations.filter {
            $0.windowEndedAt <= targetObservationCutoff &&
                $0.isFullyContained(in: epochs.target)
        }
        let fiveHour = projection(
            for: .fiveHour,
            observations: currentEpochObservations,
            relativeCapacity: configuration.targetRelativeCapacity,
            reservePercent: configuration.reservePercent
        )
        let weekly = projection(
            for: .weekly,
            observations: currentEpochObservations,
            relativeCapacity: configuration.targetRelativeCapacity,
            reservePercent: configuration.reservePercent
        )
        let targetFiveHour = projection(
            for: .fiveHour,
            observations: targetEpochObservations,
            relativeCapacity: 1,
            reservePercent: configuration.reservePercent
        )
        let targetWeekly = projection(
            for: .weekly,
            observations: targetEpochObservations,
            relativeCapacity: 1,
            reservePercent: configuration.reservePercent
        )
        let status: CodexPlanTransitionObservationStatus =
            fiveHour.observationStatus == .sufficient && weekly.observationStatus == .sufficient
            ? .sufficient
            : .insufficient

        return CodexPlanTransitionScenario(
            basisLabel: "사용자 설정 기반 예상",
            observationStatus: status,
            transitionStatus: transitionStatus(
                configuration: configuration,
                targetObservationStatus: targetFiveHour.observationStatus,
                now: now
            ),
            fiveHour: fiveHour,
            weekly: weekly,
            targetFiveHour: targetFiveHour,
            targetWeekly: targetWeekly,
            fiveHourP90DeltaPercent: difference(
                actual: targetFiveHour.observedP90Percent,
                projected: fiveHour.projectedP90Percent
            )
        )
    }

    private func projection(
        for window: CodexPlanTransitionWindow,
        observations: [CodexPlanTransitionObservation],
        relativeCapacity: Double,
        reservePercent: Double
    ) -> CodexPlanTransitionProjection {
        let peaks = windowPeaks(
            observations.filter { $0.window == window }
        )
        let duration = observationDuration(peaks)
        let status: CodexPlanTransitionObservationStatus =
            peaks.count >= minimumObservationCount && duration >= minimumObservationDurationSeconds
            ? .sufficient
            : .insufficient
        let observed = peaks.map(\.usedPercent).sorted()
        let projected = observed.map { $0 / relativeCapacity }

        return CodexPlanTransitionProjection(
            observationStatus: status,
            observationCount: peaks.count,
            observationDurationSeconds: duration,
            observedP50Percent: status == .sufficient ? percentile(0.50, values: observed) : nil,
            observedP90Percent: status == .sufficient ? percentile(0.90, values: observed) : nil,
            observedMaximumPercent: status == .sufficient ? observed.max() : nil,
            projectedP50Percent: status == .sufficient ? percentile(0.50, values: projected) : nil,
            projectedP90Percent: status == .sufficient ? percentile(0.90, values: projected) : nil,
            projectedMaximumPercent: status == .sufficient ? projected.max() : nil,
            reserveShortfallWindowCount: status == .sufficient
                ? projected.filter { $0 > 100 - reservePercent }.count
                : 0,
            limitExceededWindowCount: status == .sufficient
                ? projected.filter { $0 > 100 }.count
                : 0
        )
    }

    private func windowPeaks(
        _ observations: [CodexPlanTransitionObservation]
    ) -> [CodexPlanTransitionObservation] {
        var groups: [[CodexPlanTransitionObservation]] = []
        for observation in observations.sorted(by: { $0.windowEndedAt < $1.windowEndedAt }) {
            if let index = groups.lastIndex(where: { group in
                guard let first = group.first,
                      first.window == observation.window,
                      first.planEpochID == observation.planEpochID
                else {
                    return false
                }
                let tolerance = observation.window == .fiveHour
                    ? CodexUsageFiveHourHistorySample.logicalWindowTimestampToleranceSeconds
                    : 0
                return abs(first.windowEndedAt - observation.windowEndedAt) <= tolerance
            }) {
                groups[index].append(observation)
            } else {
                groups.append([observation])
            }
        }
        return groups.compactMap { samples in
            samples.max { lhs, rhs in
                if lhs.usedPercent != rhs.usedPercent {
                    return lhs.usedPercent < rhs.usedPercent
                }
                return lhs.recordedAt < rhs.recordedAt
            }
        }
        .sorted { $0.windowEndedAt < $1.windowEndedAt }
    }

    private func observationDuration(
        _ observations: [CodexPlanTransitionObservation]
    ) -> Int {
        guard let first = observations.map(\.windowStartedAt).min(),
              let last = observations.map(\.windowEndedAt).max()
        else {
            return 0
        }
        return max(last - first, 0)
    }

    private func percentile(_ percentile: Double, values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let rank = max(1, Int(ceil(percentile * Double(sorted.count))))
        return sorted[min(rank - 1, sorted.count - 1)]
    }

    private func transitionStatus(
        configuration: CodexPlanTransitionConfiguration,
        targetObservationStatus: CodexPlanTransitionObservationStatus,
        now: Int
    ) -> CodexPlanTransitionStatus {
        if let confirmedAt = configuration.confirmedTransitionAt {
            if now < confirmedAt {
                return .planned(at: confirmedAt)
            }
            let observedThrough = confirmedAt + 7 * 24 * 60 * 60
            if now < observedThrough {
                return .observing(until: observedThrough)
            }
            return targetObservationStatus == .sufficient
                ? .completed(observedThrough: observedThrough)
                : .awaitingObservations(since: confirmedAt)
        }
        if let plannedAt = configuration.plannedTransitionAt {
            return .planned(at: plannedAt)
        }
        return .notScheduled
    }

    private func difference(actual: Double?, projected: Double?) -> Double? {
        guard let actual, let projected else { return nil }
        return actual - projected
    }
}
