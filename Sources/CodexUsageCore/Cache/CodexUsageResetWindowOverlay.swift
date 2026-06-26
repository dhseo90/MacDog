import Foundation

public struct CodexUsageResetWindowOverlayModel: Equatable, Sendable {
    public let windows: [CodexUsageResetWindowOverlayWindow]
    public let selectedWindow: CodexUsageResetWindowOverlayWindow?
    public let selectedSeries: CodexUsageResetWindowOverlaySeries?

    public init(
        windows: [CodexUsageResetWindowOverlayWindow],
        selectedWindow: CodexUsageResetWindowOverlayWindow?,
        selectedSeries: CodexUsageResetWindowOverlaySeries?
    ) {
        self.windows = windows
        self.selectedWindow = selectedWindow
        self.selectedSeries = selectedSeries
    }
}

public struct CodexUsageResetWindowOverlayWindow: Equatable, Identifiable, Sendable {
    public let key: CodexUsageResetWindowHistoryKey
    public let resetStartAt: Int
    public let resetsAt: Int
    public let finalUsedPercent: Double
    public let finalRemainingPercent: Double
    public let sampleCount: Int
    public let source: CodexUsageResetWindowHistorySource

    public var id: String {
        "\(key.limitId)-\(key.windowDurationMins)-\(key.resetsAt)"
    }

    public init(record: CodexUsageResetWindowHistoryRecord) {
        self.key = record.key
        self.resetStartAt = record.resetStartAt
        self.resetsAt = record.resetsAt
        self.finalUsedPercent = record.finalUsedPercent
        self.finalRemainingPercent = record.finalRemainingPercent
        self.sampleCount = record.sampleCount
        self.source = record.source
    }
}

public struct CodexUsageResetWindowOverlaySeries: Equatable, Sendable {
    public let key: CodexUsageResetWindowHistoryKey
    public let timelineStartDay: Double
    public let timelineEndDay: Double
    public let resetStartMarker: CodexUsageResetWindowOverlayMarker
    public let dayEndMarkers: [CodexUsageResetWindowOverlayMarker]
    public let sevenDayEndMarker: CodexUsageResetWindowOverlayMarker?
    public let finalUsageMarker: CodexUsageResetWindowOverlayMarker
    public let linePoints: [CodexUsageResetWindowOverlayMarker]

    public init(
        key: CodexUsageResetWindowHistoryKey,
        timelineStartDay: Double,
        timelineEndDay: Double,
        resetStartMarker: CodexUsageResetWindowOverlayMarker,
        dayEndMarkers: [CodexUsageResetWindowOverlayMarker],
        sevenDayEndMarker: CodexUsageResetWindowOverlayMarker?,
        finalUsageMarker: CodexUsageResetWindowOverlayMarker,
        linePoints: [CodexUsageResetWindowOverlayMarker]
    ) {
        self.key = key
        self.timelineStartDay = timelineStartDay
        self.timelineEndDay = timelineEndDay
        self.resetStartMarker = resetStartMarker
        self.dayEndMarkers = dayEndMarkers
        self.sevenDayEndMarker = sevenDayEndMarker
        self.finalUsageMarker = finalUsageMarker
        self.linePoints = linePoints
    }
}

public enum CodexUsageResetWindowOverlayMarkerKind: Equatable, Sendable {
    case resetStart
    case dayEnd
    case sevenDayEnd
    case finalUsage
}

public struct CodexUsageResetWindowOverlayMarker: Equatable, Identifiable, Sendable {
    public let id: String
    public let kind: CodexUsageResetWindowOverlayMarkerKind
    public let day: Double
    public let timelinePosition: Double
    public let recordedAt: Int
    public let usedPercent: Double
    public let remainingPercent: Double

    public init(
        id: String,
        kind: CodexUsageResetWindowOverlayMarkerKind,
        day: Double,
        recordedAt: Int,
        usedPercent: Double,
        remainingPercent: Double
    ) {
        self.id = id
        self.kind = kind
        self.day = min(max(day, 0), 7)
        self.timelinePosition = min(max(day / 7, 0), 1)
        self.recordedAt = recordedAt
        self.usedPercent = Self.clampedPercent(usedPercent)
        self.remainingPercent = Self.clampedPercent(remainingPercent)
    }

    private static func clampedPercent(_ value: Double) -> Double {
        min(max(value, 0), 100)
    }
}

public struct CodexUsageResetWindowOverlayBuilder: Sendable {
    public static let weeklyWindowDurationMins = 10_080
    public static let resetTimestampToleranceSeconds = 60

    public init() {}

    public func model(
        history: CodexUsageResetWindowHistory,
        selectedKey: CodexUsageResetWindowHistoryKey?,
        limitId: String = "codex",
        excludingCurrentResetsAt currentResetsAt: Int? = nil
    ) -> CodexUsageResetWindowOverlayModel {
        let windows = pastWeeklyWindows(
            in: history,
            limitId: limitId,
            excludingCurrentResetsAt: currentResetsAt
        )
        let selectedWindow = windows.first { $0.key == selectedKey } ?? windows.first
        let selectedRecord = selectedWindow.flatMap { window in
            history.records.first { $0.key == window.key }
        }
        let selectedSeries = selectedRecord.map(series)

        return CodexUsageResetWindowOverlayModel(
            windows: windows,
            selectedWindow: selectedWindow,
            selectedSeries: selectedSeries
        )
    }

    public func pastWeeklyWindows(
        in history: CodexUsageResetWindowHistory,
        limitId: String = "codex",
        excludingCurrentResetsAt currentResetsAt: Int? = nil
    ) -> [CodexUsageResetWindowOverlayWindow] {
        history.records
            .filter { record in
                record.limitId == limitId &&
                    record.windowDurationMins == Self.weeklyWindowDurationMins &&
                    !Self.isCurrentReset(record.resetsAt, currentResetsAt: currentResetsAt)
            }
            .sorted { $0.resetsAt > $1.resetsAt }
            .map(CodexUsageResetWindowOverlayWindow.init(record:))
    }

    private static func isCurrentReset(_ resetsAt: Int, currentResetsAt: Int?) -> Bool {
        guard let currentResetsAt else { return false }
        return abs(resetsAt - currentResetsAt) <= resetTimestampToleranceSeconds
    }

    public func series(for record: CodexUsageResetWindowHistoryRecord) -> CodexUsageResetWindowOverlaySeries {
        let resetStartMarker = CodexUsageResetWindowOverlayMarker(
            id: "\(record.key.limitId)-\(record.key.resetsAt)-start",
            kind: .resetStart,
            day: 0,
            recordedAt: record.resetStartAt,
            usedPercent: 0,
            remainingPercent: 100
        )
        let dayEndMarkers = record.dailyEndSamples.map { sample in
            let day = Double(sample.dayIndex)
            return CodexUsageResetWindowOverlayMarker(
                id: "\(record.key.limitId)-\(record.key.resetsAt)-day-\(sample.dayIndex)",
                kind: sample.dayIndex == 7 ? .sevenDayEnd : .dayEnd,
                day: day,
                recordedAt: sample.recordedAt,
                usedPercent: sample.usedPercent,
                remainingPercent: sample.remainingPercent
            )
        }
        let finalUsageMarker = CodexUsageResetWindowOverlayMarker(
            id: "\(record.key.limitId)-\(record.key.resetsAt)-final",
            kind: .finalUsage,
            day: 7,
            recordedAt: record.generatedAt,
            usedPercent: record.finalUsedPercent,
            remainingPercent: record.finalRemainingPercent
        )

        return CodexUsageResetWindowOverlaySeries(
            key: record.key,
            timelineStartDay: 0,
            timelineEndDay: 7,
            resetStartMarker: resetStartMarker,
            dayEndMarkers: dayEndMarkers,
            sevenDayEndMarker: dayEndMarkers.last { $0.kind == .sevenDayEnd },
            finalUsageMarker: finalUsageMarker,
            linePoints: [resetStartMarker] + dayEndMarkers + [finalUsageMarker]
        )
    }
}
