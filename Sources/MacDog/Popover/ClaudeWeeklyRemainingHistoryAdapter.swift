import CodexUsageCore

enum ClaudeWeeklyRemainingHistoryAdapter {
    static let weeklyWindowDurationMins = ClaudeUsageWindowKind.sevenDay.windowDurationMins

    static func weeklyWindow(_ window: ClaudeUsageWindowSnapshot) -> UsageWindowReport? {
        guard let usedPercent = window.usedPercent,
              let resetsAt = window.resetsAt,
              resetsAt > 0 else {
            return nil
        }
        return UsageWindowReport(
            kind: .weekly,
            usedPercent: usedPercent,
            remainingPercent: 100 - usedPercent,
            windowDurationMins: weeklyWindowDurationMins,
            resetsAt: resetsAt
        )
    }

    static func history(
        _ history: ClaudeUsageHistory,
        currentWeekly: ClaudeUsageWindowSnapshot? = nil,
        currentRecordedAt: Int? = nil
    ) -> CodexUsageWeeklyHistory {
        var samples = history.samples.compactMap(sample(from:))
        if let currentWeekly,
           let currentRecordedAt,
           let current = sample(
            recordedAt: currentRecordedAt,
            usedPercent: currentWeekly.usedPercent,
            resetsAt: currentWeekly.resetsAt
           ),
           !samples.contains(where: { $0.recordedAt == current.recordedAt }) {
            samples.append(current)
        }
        return CodexUsageWeeklyHistory(samples: samples)
    }

    private static func sample(from sample: ClaudeUsageHistorySample) -> CodexUsageWeeklyHistorySample? {
        guard sample.kind == .sevenDay else { return nil }
        return self.sample(
            recordedAt: sample.recordedAt,
            usedPercent: sample.usedPercent,
            resetsAt: sample.resetsAt
        )
    }

    private static func sample(
        recordedAt: Int,
        usedPercent: Double?,
        resetsAt: Int?
    ) -> CodexUsageWeeklyHistorySample? {
        guard recordedAt > 0,
              let usedPercent,
              let resetsAt,
              resetsAt > 0 else {
            return nil
        }
        return CodexUsageWeeklyHistorySample(
            recordedAt: recordedAt,
            usedPercent: usedPercent,
            remainingPercent: 100 - usedPercent,
            resetsAt: resetsAt,
            windowDurationMins: weeklyWindowDurationMins
        )
    }
}
