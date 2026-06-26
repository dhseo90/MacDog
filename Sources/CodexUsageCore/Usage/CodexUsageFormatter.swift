import Foundation

public struct CodexUsageFormatter: Sendable {
    private let timeZone: TimeZone
    private let locale: Locale

    public init(
        timeZone: TimeZone = .current,
        locale: Locale = .current
    ) {
        self.timeZone = timeZone
        self.locale = locale
    }

    public func text(from report: CodexUsageReport) -> String {
        guard let limit = report.codexLimit else {
            return "Codex usage\nNo codex usage bucket found."
        }

        var lines = ["Codex usage"]
        lines.append(format(label: "5h", window: limit.fiveHour))
        lines.append(format(label: "Weekly", window: limit.weekly))
        lines.append("Credits: \(limit.credits?.balance ?? "unknown")")
        lines.append("Plan: \(CodexUsagePlanDisplay.displayLabel(rawPlanType: limit.planType ?? report.planType))")

        if let reached = limit.rateLimitReachedType ?? report.rateLimitReachedType {
            lines.append("Limit status: \(reached)")
        }

        return lines.joined(separator: "\n")
    }

    public func json(from report: CodexUsageReport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(report)
    }

    private func format(label: String, window: UsageWindowReport?) -> String {
        guard let window else {
            return "\(label): unavailable"
        }

        let used = formatPercent(window.usedPercent)
        let remaining = formatPercent(window.remainingPercent)
        let reset = window.resetsAt.map(formatEpoch) ?? "unknown"
        return "\(label): \(used)% used, \(remaining)% remaining, resets \(reset)"
    }

    private func formatPercent(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    private func formatEpoch(_ epoch: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(epoch))
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm zzz"
        return formatter.string(from: date)
    }
}

public struct CodexUsageCacheWriteDiagnosticFormatter: Sendable {
    public init() {}

    public func line(from result: CodexUsageCacheWriteResult) -> String {
        weeklyHistoryLine(from: result.weeklyHistory)
    }

    public func lines(from result: CodexUsageCacheWriteResult) -> [String] {
        [
            weeklyHistoryLine(from: result.weeklyHistory),
            resetWindowHistoryLine(from: result.resetWindowHistory)
        ]
    }

    private func weeklyHistoryLine(from history: CodexUsageWeeklyHistoryWriteResult) -> String {
        return [
            "history append:",
            history.disposition.rawValue,
            "recordedAt=\(history.recordedAt.map(formatEpoch) ?? "unavailable")",
            "recordingStartedAt=\(history.recordingStartedAt.map(formatEpoch) ?? "unavailable")",
            "remaining=\(history.remainingPercent.map(formatPercent) ?? "unavailable")",
            "resetsAt=\(history.resetsAt.map(formatEpoch) ?? "unavailable")",
            "path=\(history.fileURL.path)"
        ].joined(separator: " ")
    }

    private func resetWindowHistoryLine(from history: CodexUsageResetWindowHistoryWriteResult) -> String {
        [
            "reset window history append:",
            history.disposition.rawValue,
            "recordedAt=\(history.recordedAt.map(formatEpoch) ?? "unavailable")",
            "remaining=\(history.remainingPercent.map(formatPercent) ?? "unavailable")",
            "resetsAt=\(history.resetsAt.map(formatEpoch) ?? "unavailable")",
            "windowDurationMins=\(history.windowDurationMins.map(String.init) ?? "unavailable")",
            "sampleCount=\(history.sampleCount.map(String.init) ?? "unavailable")",
            "source=\(history.source?.rawValue ?? "unavailable")",
            "path=\(history.fileURL.path)"
        ].joined(separator: " ")
    }

    private func formatPercent(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value))%"
        }
        return "\(String(format: "%.1f", value))%"
    }

    private func formatEpoch(_ epoch: Int) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(epoch)))
    }
}
