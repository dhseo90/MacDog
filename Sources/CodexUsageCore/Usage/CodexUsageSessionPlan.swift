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

    fileprivate func seconds(using projection: CodexUsagePaceProjection) -> Int {
        switch self {
        case .oneHour:
            3_600
        case .threeHours:
            10_800
        case .untilReset:
            projection.remainingSeconds ?? 0
        }
    }
}

public enum CodexUsageSessionPlanState: String, Equatable, Sendable {
    case safe
    case watch
    case risky
    case unavailable
}

public struct CodexUsageSessionPlan: Equatable, Sendable {
    public let duration: CodexUsageSessionPlanDuration
    public let durationSeconds: Int
    public let state: CodexUsageSessionPlanState
    public let title: String
    public let currentUsedPercent: Double?
    public let projectedUsedPercent: Double?
    public let usedPercentPerHour: Double?
    public let sampleCount: Int

    public init(
        duration: CodexUsageSessionPlanDuration,
        durationSeconds: Int,
        state: CodexUsageSessionPlanState,
        title: String,
        currentUsedPercent: Double?,
        projectedUsedPercent: Double?,
        usedPercentPerHour: Double?,
        sampleCount: Int
    ) {
        self.duration = duration
        self.durationSeconds = max(0, durationSeconds)
        self.state = state
        self.title = title
        self.currentUsedPercent = currentUsedPercent.map(Self.clampedPercent)
        self.projectedUsedPercent = projectedUsedPercent.map(Self.clampedPercent)
        self.usedPercentPerHour = usedPercentPerHour.map { max(0, $0) }
        self.sampleCount = max(0, sampleCount)
    }

    private static func clampedPercent(_ value: Double) -> Double {
        min(max(value, 0), 100)
    }
}

public struct CodexUsageSessionPlanBuilder: Sendable {
    public init() {}

    public func plan(
        duration: CodexUsageSessionPlanDuration,
        snapshot: CodexUsageCacheSnapshot,
        weeklyHistory: CodexUsageWeeklyHistory,
        now: Date = Date()
    ) -> CodexUsageSessionPlan {
        let projection = CodexUsagePaceProjectionBuilder().projection(
            snapshot: snapshot,
            weeklyHistory: weeklyHistory,
            now: now
        )
        let durationSeconds = duration.seconds(using: projection)

        guard projection.state == .projected,
              let currentUsedPercent = projection.currentUsedPercent,
              let usedPercentPerHour = projection.usedPercentPerHour
        else {
            return CodexUsageSessionPlan(
                duration: duration,
                durationSeconds: durationSeconds,
                state: .unavailable,
                title: Self.title(for: .unavailable, duration: duration),
                currentUsedPercent: projection.currentUsedPercent,
                projectedUsedPercent: nil,
                usedPercentPerHour: projection.usedPercentPerHour,
                sampleCount: projection.sampleCount
            )
        }

        let projectedUsedPercent = Self.clampedPercent(
            currentUsedPercent + usedPercentPerHour / 3_600 * Double(durationSeconds)
        )
        let state = Self.state(projectedUsedPercent: projectedUsedPercent)

        return CodexUsageSessionPlan(
            duration: duration,
            durationSeconds: durationSeconds,
            state: state,
            title: Self.title(for: state, duration: duration),
            currentUsedPercent: currentUsedPercent,
            projectedUsedPercent: projectedUsedPercent,
            usedPercentPerHour: usedPercentPerHour,
            sampleCount: projection.sampleCount
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

    private static func title(
        for state: CodexUsageSessionPlanState,
        duration: CodexUsageSessionPlanDuration
    ) -> String {
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

    private static func clampedPercent(_ value: Double) -> Double {
        min(max(value, 0), 100)
    }
}
