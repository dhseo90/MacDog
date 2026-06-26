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
        self.overlayModel = CodexUsageResetWindowOverlayBuilder().model(
            history: resetWindowHistory,
            selectedKey: nil,
            excludingCurrentResetsAt: weeklyWindow.resetsAt
        )
    }

    var pastWindows: [CodexUsageResetWindowOverlayWindow] {
        overlayModel.windows
    }

    var availableModes: [CodexUsageHistoryGraphMode] {
        pastWindows.isEmpty ? [.current] : CodexUsageHistoryGraphMode.allCases
    }

    var defaultPastWindowKey: CodexUsageResetWindowHistoryKey? {
        overlayModel.selectedWindow?.key
    }

    var overlaySeries: CodexUsageResetWindowOverlaySeries? {
        overlayModel.selectedSeries
    }
}

enum CodexUsageHistoryMarkerLabel {
    static func hoverText(for marker: CodexUsageResetWindowOverlayMarker) -> String {
        switch marker.kind {
        case .resetStart:
            return "시작 · 사용 0%"
        case .dayEnd:
            return "\(UsageMonitorState.percent(marker.day))일 종료 · 사용 \(UsageMonitorState.percent(marker.usedPercent))%"
        case .sevenDayEnd:
            return "7일 종료 · 사용 \(UsageMonitorState.percent(marker.usedPercent))%"
        case .finalUsage:
            return "최종 · 사용 \(UsageMonitorState.percent(marker.usedPercent))%"
        }
    }
}
