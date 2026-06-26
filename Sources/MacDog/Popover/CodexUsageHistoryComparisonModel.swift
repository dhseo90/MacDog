import CodexUsageCore
import Foundation

enum CodexUsageHistoryGraphMode: String, CaseIterable, Equatable, Identifiable {
    case current
    case past
    case overlay

    var id: String { rawValue }

    var label: String {
        switch self {
        case .current:
            return "현재"
        case .past:
            return "지난"
        case .overlay:
            return "비교"
        }
    }
}

struct CodexUsageHistoryComparisonModel: Equatable {
    let currentChart: WeeklyRemainingHistoryChart
    let resetWindowHistory: CodexUsageResetWindowHistory
    let overlayModel: CodexUsageResetWindowOverlayModel

    init?(
        state: UsageMonitorState,
        calendar: Calendar = .current
    ) {
        self.init(
            history: state.weeklyUsageHistory,
            resetWindowHistory: state.resetWindowHistory,
            weeklyWindow: state.codexLimit?.weekly,
            currentReport: state.report,
            currentTimestamp: state.cacheSnapshot?.cachedAt ?? state.report?.generatedAt,
            calendar: calendar
        )
    }

    init?(
        history: CodexUsageWeeklyHistory,
        resetWindowHistory: CodexUsageResetWindowHistory,
        weeklyWindow: UsageWindowReport?,
        currentReport: CodexUsageReport?,
        currentTimestamp: Int?,
        calendar: Calendar = .current
    ) {
        guard let weeklyWindow else {
            return nil
        }

        let currentSample: CodexUsageWeeklyHistorySample?
        if let currentReport,
           let currentTimestamp {
            currentSample = CodexUsageWeeklyHistorySample(
                report: currentReport,
                recordedAt: currentTimestamp
            )
        } else {
            currentSample = nil
        }

        self.currentChart = WeeklyRemainingHistoryChart(
            history: history,
            weeklyWindow: weeklyWindow,
            currentSample: currentSample,
            calendar: calendar
        )
        self.resetWindowHistory = Self.resetWindowHistory(
            resetWindowHistory,
            backfilledFrom: history,
            weeklyWindow: weeklyWindow,
            referenceTimestamp: currentTimestamp
        )
        self.overlayModel = CodexUsageResetWindowOverlayBuilder().model(
            history: self.resetWindowHistory,
            selectedKey: nil,
            excludingCurrentResetsAt: weeklyWindow.resetsAt
        )
    }

    var pastWindows: [CodexUsageResetWindowOverlayWindow] {
        overlayModel.windows
    }

    var availableModes: [CodexUsageHistoryGraphMode] {
        CodexUsageHistoryGraphMode.allCases
    }

    var defaultPastWindowKey: CodexUsageResetWindowHistoryKey? {
        overlayModel.selectedWindow?.key
    }

    var overlaySeries: CodexUsageResetWindowOverlaySeries? {
        overlayModel.selectedSeries
    }

    private static func resetWindowHistory(
        _ resetWindowHistory: CodexUsageResetWindowHistory,
        backfilledFrom weeklyHistory: CodexUsageWeeklyHistory,
        weeklyWindow: UsageWindowReport,
        referenceTimestamp: Int?
    ) -> CodexUsageResetWindowHistory {
        guard let referenceTimestamp else {
            return resetWindowHistory
        }

        let summaries = CodexUsageResetWindowBackfillBuilder().summaries(
            from: weeklyHistory,
            completedAtOrBefore: referenceTimestamp,
            excludingCurrentResetsAt: weeklyWindow.resetsAt
        )
        let backfilledRecords = summaries.map {
            CodexUsageResetWindowBackfillBuilder().record(from: $0)
        }
        let existingKeys = Set(resetWindowHistory.records.map(\.key))
        return CodexUsageResetWindowHistory(
            records: resetWindowHistory.records + backfilledRecords.filter { !existingKeys.contains($0.key) }
        )
    }
}

enum CodexUsageHistoryMarkerLabel {
    static func hoverText(
        for marker: CodexUsageResetWindowOverlayMarker,
        calendar: Calendar = .current
    ) -> String {
        let dateLabel = CodexUsageHistoryTimelineLabel.dayLabel(
            timestamp: marker.recordedAt,
            calendar: calendar
        )
        let remaining = UsageMonitorState.percent(marker.remainingPercent)

        switch marker.kind {
        case .resetStart:
            return "\(dateLabel) 시작 · \(remaining)%"
        case .dayEnd:
            return "\(dateLabel) 종료 · \(remaining)%"
        case .sevenDayEnd:
            return "\(dateLabel) 종료 · \(remaining)%"
        case .finalUsage:
            return "\(dateLabel) 최종 · \(remaining)%"
        }
    }
}

enum CodexUsageHistoryTimelineLabel {
    static func startLabel(
        for series: CodexUsageResetWindowOverlaySeries?,
        calendar: Calendar = .current
    ) -> String {
        guard let series else { return "" }
        return "기록 시작 \(dayTimeLabel(timestamp: series.resetStartMarker.recordedAt, calendar: calendar))"
    }

    static func endLabel(
        for series: CodexUsageResetWindowOverlaySeries?,
        calendar: Calendar = .current
    ) -> String {
        guard let series else { return "" }
        return dayLabel(timestamp: series.key.resetsAt, calendar: calendar)
    }

    static func windowLabel(
        for window: CodexUsageResetWindowOverlayWindow,
        calendar: Calendar = .current
    ) -> String {
        let start = shortDateLabel(timestamp: window.resetStartAt, calendar: calendar)
        let end = shortDateLabel(timestamp: window.resetsAt, calendar: calendar)
        return "\(start)-\(end)"
    }

    static func dayLabel(timestamp: Int, calendar inputCalendar: Calendar = .current) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let components = inputCalendar.dateComponents([.month, .day, .weekday], from: date)
        let month = components.month ?? 0
        let day = components.day ?? 0
        let weekday = weekdaySymbol(for: components.weekday)
        return "\(month)/\(day) \(weekday)"
    }

    private static func dayTimeLabel(timestamp: Int, calendar inputCalendar: Calendar) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let components = inputCalendar.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return "\(dayLabel(timestamp: timestamp, calendar: inputCalendar)) \(String(format: "%02d:%02d", hour, minute))"
    }

    private static func shortDateLabel(timestamp: Int, calendar inputCalendar: Calendar) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let components = inputCalendar.dateComponents([.month, .day], from: date)
        let month = components.month ?? 0
        let day = components.day ?? 0
        return "\(month)/\(day)"
    }

    private static func weekdaySymbol(for weekday: Int?) -> String {
        let symbols = ["일", "월", "화", "수", "목", "금", "토"]
        guard let weekday, (1...7).contains(weekday) else { return "?" }
        return symbols[weekday - 1]
    }
}
