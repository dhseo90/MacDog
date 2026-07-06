import Foundation

public struct CodexUsageFormatter: Sendable {
    private let timeZone: TimeZone
    private let locale: Locale
    private let now: @Sendable () -> Date

    public init(
        timeZone: TimeZone = .current,
        locale: Locale = .current,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.timeZone = timeZone
        self.locale = locale
        self.now = now
    }

    public func text(from report: CodexUsageReport) -> String {
        guard let limit = report.codexLimit else {
            return "Codex usage\nNo codex usage bucket found."
        }

        var lines = ["Codex usage"]
        lines.append(format(label: "5h", window: limit.fiveHour))
        lines.append(format(label: "Weekly", window: limit.weekly))
        lines.append("Credits: \(limit.credits?.balance ?? "unknown")")
        lines.append(contentsOf: resetCreditLines(from: report.resetCredits))
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

    private func resetCreditLines(from summary: RateLimitResetCreditsSummary?) -> [String] {
        guard let summary else {
            return ["Reset credits: unknown"]
        }

        var lines = ["Reset credits: \(summary.availableCount) available"]
        guard summary.availableCount > 0 else {
            return lines
        }

        let expiries = summary.credits.compactMap(\.expiresAt)
        if expiries.isEmpty {
            lines.append("Reset credit expiry: unavailable")
        } else {
            let formattedExpiries = expiries.map(formatResetCreditExpiry).joined(separator: ", ")
            lines.append("Reset credit expiries: \(formattedExpiries)")
        }
        return lines
    }

    private func formatResetCreditExpiry(_ rawValue: String) -> String {
        guard let date = parseISO8601Date(rawValue) else {
            return rawValue
        }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm zzz"
        return formatter.string(from: date)
    }

    private func parseISO8601Date(_ rawValue: String) -> Date? {
        let fractionalParser = ISO8601DateFormatter()
        fractionalParser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalParser.date(from: rawValue) {
            return date
        }

        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime]
        return parser.date(from: rawValue)
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
