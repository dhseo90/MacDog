import Foundation

public enum CodexUsageSessionPlanDuration: String, CaseIterable, Equatable, Identifiable, Sendable {
    case oneHour
    case threeHours
    case untilReset

    public var id: String {
        rawValue
    }

    public var label: String {
        switch self {
        case .oneHour:
            "1시간"
        case .threeHours:
            "3시간"
        case .untilReset:
            "reset까지"
        }
    }

    fileprivate func seconds(using projection: CodexUsagePaceProjection) -> Int? {
        switch self {
        case .oneHour:
            3_600
        case .threeHours:
            10_800
        case .untilReset:
            projection.remainingSeconds
        }
    }
}

public enum CodexUsageSessionPlanState: String, Equatable, Sendable {
    case safe
    case watch
    case risky
    case unavailable
}

public enum CodexUsageSessionPlanAvailability: String, Equatable, Sendable {
    case ready
    case missingSnapshot
    case waitingForSamples
    case stale
    case error
    case unavailable
}

public struct CodexUsageSessionPlan: Equatable, Sendable {
    public let duration: CodexUsageSessionPlanDuration
    public let durationSeconds: Int?
    public let state: CodexUsageSessionPlanState
    public let availability: CodexUsageSessionPlanAvailability
    public let currentUsedPercent: Double?
    public let projectedUsedPercentAtEnd: Double?
    public let usedPercentPerHour: Double?
    public let sampleCount: Int

    public var title: String {
        switch state {
        case .safe:
            "\(duration.label) 작업 여유"
        case .watch:
            "\(duration.label) 작업 주의"
        case .risky:
            "\(duration.label) 작업 위험"
        case .unavailable:
            "작업 계획 대기"
        }
    }

    public var detail: String {
        if let projectedUsedPercentAtEnd {
            return "예상 사용률 \(Self.roundedPercentText(projectedUsedPercentAtEnd))"
        }

        switch availability {
        case .ready, .missingSnapshot, .unavailable:
            return "사용량 데이터가 준비되면 예상 사용률을 표시합니다."
        case .waitingForSamples:
            return "샘플이 더 쌓이면 예상 사용률을 표시합니다."
        case .stale:
            return "최신 cache가 확인되면 예상 사용률을 표시합니다."
        case .error:
            return "오류 상태라 작업 계획을 계산하지 않습니다."
        }
    }

    public init(
        duration: CodexUsageSessionPlanDuration,
        durationSeconds: Int?,
        state: CodexUsageSessionPlanState,
        availability: CodexUsageSessionPlanAvailability,
        currentUsedPercent: Double?,
        projectedUsedPercentAtEnd: Double?,
        usedPercentPerHour: Double?,
        sampleCount: Int
    ) {
        self.duration = duration
        self.durationSeconds = durationSeconds.map { max(0, $0) }
        self.state = state
        self.availability = availability
        self.currentUsedPercent = currentUsedPercent.map(Self.clampedPercent)
        self.projectedUsedPercentAtEnd = projectedUsedPercentAtEnd.map(Self.clampedPercent)
        self.usedPercentPerHour = usedPercentPerHour.map { max(0, $0) }
        self.sampleCount = max(0, sampleCount)
    }

    private static func clampedPercent(_ value: Double) -> Double {
        min(max(value, 0), 100)
    }

    private static func roundedPercentText(_ value: Double) -> String {
        "\(Int(clampedPercent(value).rounded()))%"
    }
}

public struct CodexUsageSessionPlanBuilder: Sendable {
    public init() {}

    public func plan(
        snapshot: CodexUsageCacheSnapshot?,
        weeklyHistory: CodexUsageWeeklyHistory,
        duration: CodexUsageSessionPlanDuration,
        now: Date = Date()
    ) -> CodexUsageSessionPlan {
        guard let snapshot else {
            return unavailablePlan(
                duration: duration,
                availability: .missingSnapshot,
                currentUsedPercent: nil,
                usedPercentPerHour: nil,
                sampleCount: 0
            )
        }

        let projection = CodexUsagePaceProjectionBuilder().projection(
            snapshot: snapshot,
            weeklyHistory: weeklyHistory,
            now: now
        )
        let availability = Self.availability(for: projection.state)

        guard projection.state == .projected,
              let currentUsedPercent = projection.currentUsedPercent,
              let usedPercentPerHour = projection.usedPercentPerHour,
              let durationSeconds = duration.seconds(using: projection)
        else {
            return unavailablePlan(
                duration: duration,
                availability: availability,
                currentUsedPercent: projection.currentUsedPercent,
                usedPercentPerHour: projection.usedPercentPerHour,
                sampleCount: projection.sampleCount
            )
        }

        let projectedUsedPercentAtEnd = Self.clampedPercent(
            currentUsedPercent + usedPercentPerHour / 3_600 * Double(durationSeconds)
        )
        let state = Self.state(projectedUsedPercent: projectedUsedPercentAtEnd)

        return CodexUsageSessionPlan(
            duration: duration,
            durationSeconds: durationSeconds,
            state: state,
            availability: .ready,
            currentUsedPercent: currentUsedPercent,
            projectedUsedPercentAtEnd: projectedUsedPercentAtEnd,
            usedPercentPerHour: usedPercentPerHour,
            sampleCount: projection.sampleCount
        )
    }

    public func plan(
        duration: CodexUsageSessionPlanDuration,
        snapshot: CodexUsageCacheSnapshot,
        weeklyHistory: CodexUsageWeeklyHistory,
        now: Date = Date()
    ) -> CodexUsageSessionPlan {
        plan(
            snapshot: snapshot,
            weeklyHistory: weeklyHistory,
            duration: duration,
            now: now
        )
    }

    private static func state(projectedUsedPercent: Double) -> CodexUsageSessionPlanState {
        switch projectedUsedPercent {
        case ..<80:
            .safe
        case 80..<95:
            .watch
        default:
            .risky
        }
    }

    private static func availability(
        for state: CodexUsagePaceProjectionState
    ) -> CodexUsageSessionPlanAvailability {
        switch state {
        case .projected:
            .ready
        case .waitingForSamples:
            .waitingForSamples
        case .stale:
            .stale
        case .error:
            .error
        case .unavailable:
            .unavailable
        }
    }

    private func unavailablePlan(
        duration: CodexUsageSessionPlanDuration,
        availability: CodexUsageSessionPlanAvailability,
        currentUsedPercent: Double?,
        usedPercentPerHour: Double?,
        sampleCount: Int
    ) -> CodexUsageSessionPlan {
        CodexUsageSessionPlan(
            duration: duration,
            durationSeconds: nil,
            state: .unavailable,
            availability: availability,
            currentUsedPercent: currentUsedPercent,
            projectedUsedPercentAtEnd: nil,
            usedPercentPerHour: usedPercentPerHour,
            sampleCount: sampleCount
        )
    }

    private static func clampedPercent(_ value: Double) -> Double {
        min(max(value, 0), 100)
    }
}
