import CodexUsageCore

enum GrokWeeklyRemainingHistoryAdapter {
    static let weeklyWindowDurationMins = 10_080

    static func weeklyWindow(_ weekly: GrokUsageWeeklyWindow) -> UsageWindowReport? {
        guard let resetsAt = weekly.resetsAt, resetsAt > 0 else {
            return nil
        }
        return UsageWindowReport(
            kind: .weekly,
            usedPercent: weekly.usedPercent,
            remainingPercent: weekly.remainingPercent,
            windowDurationMins: weeklyWindowDurationMins,
            resetsAt: resetsAt
        )
    }

    static func history(
        _ history: GrokUsageHistory,
        currentWeekly: GrokUsageWeeklyWindow? = nil,
        currentRecordedAt: Int? = nil
    ) -> CodexUsageWeeklyHistory {
        var samples = history.samples.compactMap(sample(from:))
        if let currentWeekly,
           let currentRecordedAt,
           let current = sample(
            recordedAt: currentRecordedAt,
            usedPercent: currentWeekly.usedPercent,
            remainingPercent: currentWeekly.remainingPercent,
            resetsAt: currentWeekly.resetsAt
           ),
           !samples.contains(where: { $0.recordedAt == current.recordedAt }) {
            samples.append(current)
        }
        return CodexUsageWeeklyHistory(samples: samples)
    }

    private static func sample(from grok: GrokUsageHistorySample) -> CodexUsageWeeklyHistorySample? {
        sample(
            recordedAt: grok.recordedAt,
            usedPercent: grok.usedPercent,
            remainingPercent: grok.remainingPercent,
            resetsAt: grok.resetsAt
        )
    }

    private static func sample(
        recordedAt: Int,
        usedPercent: Double,
        remainingPercent: Double,
        resetsAt: Int?
    ) -> CodexUsageWeeklyHistorySample? {
        guard recordedAt > 0, let resetsAt, resetsAt > 0 else {
            return nil
        }
        return CodexUsageWeeklyHistorySample(
            recordedAt: recordedAt,
            usedPercent: usedPercent,
            remainingPercent: remainingPercent,
            resetsAt: resetsAt,
            windowDurationMins: weeklyWindowDurationMins
        )
    }
}
