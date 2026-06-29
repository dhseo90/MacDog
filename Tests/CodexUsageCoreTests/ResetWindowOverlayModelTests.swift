import XCTest
@testable import CodexUsageCore

final class ResetWindowOverlayModelTests: XCTestCase {
    func testSelectsPastWeeklyWindowsForLimitAndDuration() {
        let currentReset = 1_800_604_800
        let pastReset = currentReset - 10_080 * 60
        let olderPastReset = pastReset - 10_080 * 60
        let history = CodexUsageResetWindowHistory(records: [
            Self.record(limitId: "codex", windowDurationMins: 10_080, resetsAt: currentReset),
            Self.record(limitId: "codex", windowDurationMins: 10_080, resetsAt: pastReset),
            Self.record(limitId: "codex", windowDurationMins: 10_080, resetsAt: olderPastReset),
            Self.record(limitId: "codex", windowDurationMins: 300, resetsAt: currentReset),
            Self.record(limitId: "codex_bengalfox", windowDurationMins: 10_080, resetsAt: pastReset)
        ])

        let windows = CodexUsageResetWindowOverlayBuilder().pastWeeklyWindows(
            in: history,
            limitId: "codex",
            excludingCurrentResetsAt: currentReset
        )

        XCTAssertEqual(windows.map(\.key.resetsAt), [pastReset, olderPastReset])
        XCTAssertTrue(windows.allSatisfy { $0.key.limitId == "codex" })
        XCTAssertTrue(windows.allSatisfy { $0.key.windowDurationMins == 10_080 })
    }

    func testExcludesCurrentWeeklyWindowWhenResetTimestampDriftsByOneSecond() {
        let currentReset = 1_800_604_800
        let driftedCurrentReset = currentReset + 1
        let pastReset = currentReset - 10_080 * 60
        let history = CodexUsageResetWindowHistory(records: [
            Self.record(limitId: "codex", windowDurationMins: 10_080, resetsAt: currentReset),
            Self.record(limitId: "codex", windowDurationMins: 10_080, resetsAt: driftedCurrentReset),
            Self.record(limitId: "codex", windowDurationMins: 10_080, resetsAt: pastReset)
        ])

        let windows = CodexUsageResetWindowOverlayBuilder().pastWeeklyWindows(
            in: history,
            limitId: "codex",
            excludingCurrentResetsAt: currentReset
        )

        XCTAssertEqual(windows.map(\.key.resetsAt), [pastReset])
    }

    func testNormalizesDailyEndMarkersOnZeroToSevenDayTimeline() throws {
        let resetsAt = 1_800_604_800
        let record = Self.record(
            limitId: "codex",
            windowDurationMins: 10_080,
            resetsAt: resetsAt,
            dailyEndSamples: [
                Self.dailySample(dayIndex: 1, usedPercent: 10, resetsAt: resetsAt),
                Self.dailySample(dayIndex: 4, usedPercent: 40, resetsAt: resetsAt),
                Self.dailySample(dayIndex: 7, usedPercent: 70, resetsAt: resetsAt)
            ],
            finalUsedPercent: 82
        )

        let series = CodexUsageResetWindowOverlayBuilder().series(for: record)

        XCTAssertEqual(series.timelineStartDay, 0)
        XCTAssertEqual(series.timelineEndDay, 7)
        XCTAssertEqual(series.dayEndMarkers.map(\.day), [1, 4, 7])
        XCTAssertEqual(series.dayEndMarkers.map(\.timelinePosition), [1.0 / 7.0, 4.0 / 7.0, 1.0])
        XCTAssertEqual(series.dayEndMarkers.map(\.usedPercent), [10, 40, 70])
        XCTAssertEqual(try XCTUnwrap(series.sevenDayEndMarker).usedPercent, 70)
    }

    func testCreatesFinalUsageMarkerAtSevenDayTimelineEnd() throws {
        let resetsAt = 1_800_604_800
        let record = Self.record(
            limitId: "codex",
            windowDurationMins: 10_080,
            resetsAt: resetsAt,
            dailyEndSamples: [
                Self.dailySample(dayIndex: 2, usedPercent: 18, resetsAt: resetsAt)
            ],
            finalUsedPercent: 83
        )

        let series = CodexUsageResetWindowOverlayBuilder().series(for: record)

        XCTAssertEqual(series.finalUsageMarker.kind, .finalUsage)
        XCTAssertEqual(series.finalUsageMarker.day, 7)
        XCTAssertEqual(series.finalUsageMarker.timelinePosition, 1)
        XCTAssertEqual(series.finalUsageMarker.usedPercent, 83)
        XCTAssertEqual(series.finalUsageMarker.remainingPercent, 17)
        XCTAssertEqual(series.linePoints.first?.kind, .resetStart)
        XCTAssertEqual(series.linePoints.first?.day, 0)
        XCTAssertEqual(series.linePoints.last, series.finalUsageMarker)
    }

    func testInterruptedWindowFinalMarkerUsesActualLastSampleDay() throws {
        let resetStartAt = 1_800_000_000
        let resetsAt = resetStartAt + 10_080 * 60
        let interruptedAt = resetStartAt + 3 * 86_400 + 16 * 60 * 60
        let record = Self.record(
            generatedAt: interruptedAt,
            limitId: "codex",
            windowDurationMins: 10_080,
            resetsAt: resetsAt,
            dailyEndSamples: [
                Self.dailySample(dayIndex: 1, usedPercent: 3, resetsAt: resetsAt),
                Self.dailySample(dayIndex: 2, usedPercent: 15, resetsAt: resetsAt),
                CodexUsageResetWindowDailySample(
                    dayIndex: 4,
                    recordedAt: interruptedAt,
                    usedPercent: 67,
                    remainingPercent: 33
                )
            ],
            finalUsedPercent: 67
        )

        let series = CodexUsageResetWindowOverlayBuilder().series(for: record)

        XCTAssertEqual(series.timelineEndDay, 7)
        XCTAssertEqual(series.finalUsageMarker.day, 3.666, accuracy: 0.001)
        XCTAssertEqual(series.finalUsageMarker.timelinePosition, 3.666 / 7, accuracy: 0.001)
        XCTAssertLessThan(series.finalUsageMarker.timelinePosition, 1)
        XCTAssertNil(series.sevenDayEndMarker)
        XCTAssertEqual(series.linePoints.last, series.finalUsageMarker)
    }

    func testModelUsesSelectedWindowAndFallsBackToMostRecentPastWindow() throws {
        let currentReset = 1_800_604_800
        let pastReset = currentReset - 10_080 * 60
        let olderPastReset = pastReset - 10_080 * 60
        let selectedKey = CodexUsageResetWindowHistoryKey(
            limitId: "codex",
            windowDurationMins: 10_080,
            resetsAt: olderPastReset
        )
        let history = CodexUsageResetWindowHistory(records: [
            Self.record(limitId: "codex", windowDurationMins: 10_080, resetsAt: currentReset),
            Self.record(limitId: "codex", windowDurationMins: 10_080, resetsAt: pastReset),
            Self.record(limitId: "codex", windowDurationMins: 10_080, resetsAt: olderPastReset)
        ])

        let selectedModel = CodexUsageResetWindowOverlayBuilder().model(
            history: history,
            selectedKey: selectedKey,
            excludingCurrentResetsAt: currentReset
        )
        let fallbackModel = CodexUsageResetWindowOverlayBuilder().model(
            history: history,
            selectedKey: nil,
            excludingCurrentResetsAt: currentReset
        )

        XCTAssertEqual(selectedModel.selectedWindow?.key, selectedKey)
        XCTAssertEqual(selectedModel.selectedSeries?.key, selectedKey)
        XCTAssertEqual(fallbackModel.selectedWindow?.key.resetsAt, pastReset)
        XCTAssertEqual(fallbackModel.selectedSeries?.key.resetsAt, pastReset)
    }

    private static func record(
        generatedAt: Int? = nil,
        limitId: String,
        windowDurationMins: Int,
        resetsAt: Int,
        dailyEndSamples: [CodexUsageResetWindowDailySample]? = nil,
        finalUsedPercent: Double = 64
    ) -> CodexUsageResetWindowHistoryRecord {
        CodexUsageResetWindowHistoryRecord(
            generatedAt: generatedAt ?? resetsAt - 60,
            limitId: limitId,
            windowDurationMins: windowDurationMins,
            resetsAt: resetsAt,
            dailyEndSamples: dailyEndSamples ?? [
                Self.dailySample(dayIndex: 7, usedPercent: finalUsedPercent, resetsAt: resetsAt)
            ],
            finalUsedPercent: finalUsedPercent,
            finalRemainingPercent: 100 - finalUsedPercent,
            sampleCount: dailyEndSamples?.count ?? 1,
            source: .liveCache
        )
    }

    private static func dailySample(
        dayIndex: Int,
        usedPercent: Double,
        resetsAt: Int
    ) -> CodexUsageResetWindowDailySample {
        CodexUsageResetWindowDailySample(
            dayIndex: dayIndex,
            recordedAt: resetsAt - (7 - dayIndex) * 24 * 60 * 60,
            usedPercent: usedPercent,
            remainingPercent: 100 - usedPercent
        )
    }
}
