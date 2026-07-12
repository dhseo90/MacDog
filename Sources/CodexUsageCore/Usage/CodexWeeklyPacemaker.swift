import Foundation

public struct CodexWeeklyPacemaker: Equatable, Sendable {
    public static let dayCount = 7
    public static let dailyTargetUsedPercent = 100.0 / Double(dayCount)
    public static let approachingRatio = 0.8

    public let windowStartAt: Int
    public let resetsAt: Int
    public let dayIndex: Int
    public let dayStartAt: Int
    public let currentUsedPercent: Double
    public let currentDayUsedPercent: Double?

    public var cumulativeTargetUsedPercent: Double {
        min(100, Self.dailyTargetUsedPercent * Double(dayIndex))
    }

    public var remainingDailyTargetPercent: Double? {
        currentDayUsedPercent.map { max(0, Self.dailyTargetUsedPercent - $0) }
    }

    public var isDailyTargetApproaching: Bool {
        guard let currentDayUsedPercent else { return false }
        return currentDayUsedPercent >= Self.dailyTargetUsedPercent * Self.approachingRatio &&
            currentDayUsedPercent <= Self.dailyTargetUsedPercent
    }

    public var isDailyTargetExceeded: Bool {
        guard let currentDayUsedPercent else { return false }
        return currentDayUsedPercent > Self.dailyTargetUsedPercent
    }

    public var isCumulativeTargetExceeded: Bool {
        currentUsedPercent > cumulativeTargetUsedPercent && cumulativeTargetUsedPercent < 100
    }
}

public struct CodexWeeklyPacemakerBuilder: Sendable {
    public static let expectedWindowDurationMins = 10_080
    public static let dayStartSampleToleranceSeconds = 15 * 60

    public init() {}

    public func pacemaker(
        weeklyWindow: UsageWindowReport?,
        history: CodexUsageWeeklyHistory,
        recordedAt: Int
    ) -> CodexWeeklyPacemaker? {
        guard let weeklyWindow,
              weeklyWindow.windowDurationMins == Self.expectedWindowDurationMins,
              let resetsAt = weeklyWindow.resetsAt
        else {
            return nil
        }

        let durationSeconds = Self.expectedWindowDurationMins * 60
        let windowStartAt = resetsAt - durationSeconds
        guard recordedAt >= windowStartAt, recordedAt < resetsAt else {
            return nil
        }

        let daySeconds = durationSeconds / CodexWeeklyPacemaker.dayCount
        let elapsed = recordedAt - windowStartAt
        let dayIndex = min(max(elapsed / daySeconds + 1, 1), CodexWeeklyPacemaker.dayCount)
        let dayStartAt = windowStartAt + (dayIndex - 1) * daySeconds
        let baselineUsedPercent = history.samples
            .filter {
                $0.matchesResetWindow(
                    resetsAt: resetsAt,
                    windowDurationMins: Self.expectedWindowDurationMins
                ) &&
                    $0.recordedAt <= dayStartAt &&
                    dayStartAt - $0.recordedAt <= Self.dayStartSampleToleranceSeconds
            }
            .max(by: { $0.recordedAt < $1.recordedAt })?
            .usedPercent

        return CodexWeeklyPacemaker(
            windowStartAt: windowStartAt,
            resetsAt: resetsAt,
            dayIndex: dayIndex,
            dayStartAt: dayStartAt,
            currentUsedPercent: weeklyWindow.usedPercent,
            currentDayUsedPercent: baselineUsedPercent.map {
                max(0, weeklyWindow.usedPercent - $0)
            }
        )
    }
}
