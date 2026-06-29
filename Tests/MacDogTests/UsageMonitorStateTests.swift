import XCTest
import CodexUsageCore
import MacDogPrivilegedHelperSupport
@testable import MacDog

final class UsageMonitorStateTests: XCTestCase {
    func testUsagePressurePhaseThresholds() {
        XCTAssertEqual(UsagePressurePhase(usedPercent: 49.9), .calm)
        XCTAssertEqual(UsagePressurePhase(usedPercent: 50), .active)
        XCTAssertEqual(UsagePressurePhase(usedPercent: 80), .fast)
        XCTAssertEqual(UsagePressurePhase(usedPercent: 95), .sprint)
        XCTAssertEqual(UsagePressurePhase(usedPercent: 100), .limit)
    }

    func testUsagePressurePhaseThresholdSummaryMatchesPopoverLegend() {
        XCTAssertEqual(UsagePressurePhase.thresholdSummary, "50% 활발 · 80% 빠름 · 95% 질주")
    }

    func testWeeklyRemainingEighteenPercentMakesRunnerFast() {
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 0, weeklyUsedPercent: 82),
            cacheSnapshot: nil,
            errorMessage: nil,
            displayBasis: .weekly
        )

        XCTAssertEqual(state.selectedUsedPercent, 82)
        XCTAssertEqual(state.selectedWindowStatus?.remainingSummary, "주간 18% 남음")
        XCTAssertEqual(state.phase, .fast)
        XCTAssertEqual(state.phase.frameInterval, 0.18)
    }

    func testMaxBasisUsesHigherCodexUsageWindowForRunnerPhase() {
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 24, weeklyUsedPercent: 82),
            cacheSnapshot: nil,
            errorMessage: nil,
            displayBasis: .max
        )

        XCTAssertEqual(state.selectedUsedPercent, 82)
        XCTAssertEqual(state.selectedWindowStatus?.label, "주간")
        XCTAssertEqual(state.phase, .fast)
    }

    func testIncompleteCodexReportDoesNotLookLikeZeroUsage() {
        let state = UsageMonitorState(
            report: Self.incompleteCodexReport(),
            cacheSnapshot: nil,
            errorMessage: nil,
            displayBasis: .weekly
        )

        XCTAssertNil(state.codexLimit)
        XCTAssertNil(state.selectedWindowStatus)
        XCTAssertEqual(state.sourceLabel, "확인 불가")
        XCTAssertEqual(state.toolTip, "코덱스 사용량 확인 불가")
    }

    func testResetSummaryShowsRemainingTimeAndCompactSameDayTime() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let calendar = Self.utcCalendar

        XCTAssertEqual(
            UsageWindowStatus.resetSummary(
                resetsAt: 1_800_007_200,
                now: now,
                calendar: calendar
            ),
            "초기화까지 2시간 남음 · 10:00"
        )
    }

    func testResetSummaryShowsCompactFutureDayTime() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let calendar = Self.utcCalendar

        XCTAssertEqual(
            UsageWindowStatus.resetSummary(
                resetsAt: 1_800_345_600,
                now: now,
                calendar: calendar
            ),
            "초기화까지 4일 남음 · 1/19 08:00"
        )
    }

    func testResetSummaryHandlesMissingAndPastResetTime() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let calendar = Self.utcCalendar

        XCTAssertEqual(
            UsageWindowStatus.resetSummary(resetsAt: nil, now: now, calendar: calendar),
            "초기화 시각 알 수 없음"
        )
        XCTAssertEqual(
            UsageWindowStatus.resetSummary(
                resetsAt: 1_799_999_940,
                now: now,
                calendar: calendar
            ),
            "초기화 확인 중 · 07:59"
        )
    }

    func testCodexPanelSummaryConnectsRiskResetsAndNotificationThresholds() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let state = UsageMonitorState(
            report: Self.report(
                fiveHourUsedPercent: 83.5,
                weeklyUsedPercent: 36,
                fiveHourResetsAt: 1_800_007_200,
                weeklyResetsAt: 1_800_345_600
            ),
            cacheSnapshot: nil,
            errorMessage: nil,
            displayBasis: .max
        )

        let summary = try XCTUnwrap(state.codexPanelSummary(now: now, calendar: Self.utcCalendar))

        XCTAssertEqual(summary.statusTitle, "사용량 높음")
        XCTAssertEqual(summary.statusDetail, "기준 5시간 83.5% 사용 / 16.5% 남음")
        XCTAssertEqual(summary.notificationThresholdSummary, "알림 기준 80/95/100% · reset 30분 전")
        XCTAssertEqual(
            summary.resetCountdowns,
            [
                CodexUsagePanelSummary.ResetCountdown(label: "5시간 reset", value: "2시간 남음 · 10:00"),
                CodexUsagePanelSummary.ResetCountdown(label: "주간 reset", value: "4일 남음 · 1/19 08:00")
            ]
        )
    }

    func testCodexPanelSummaryUsesLimitTitleWhenReportMarksLimitReached() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let state = UsageMonitorState(
            report: Self.report(
                fiveHourUsedPercent: 68,
                weeklyUsedPercent: 42,
                fiveHourResetsAt: 1_800_003_600,
                weeklyResetsAt: 1_800_604_800,
                rateLimitReachedType: "primary"
            ),
            cacheSnapshot: nil,
            errorMessage: nil
        )

        let summary = try XCTUnwrap(state.codexPanelSummary(now: now, calendar: Self.utcCalendar))

        XCTAssertEqual(summary.statusTitle, "한도 도달")
        XCTAssertEqual(summary.statusDetail, "기준 5시간 68% 사용 / 32% 남음")
        XCTAssertEqual(summary.resetCountdowns.first?.value, "1시간 남음 · 09:00")
    }

    func testRefreshingPreservesPrivilegedHelperInstallSnapshot() {
        let snapshot = PrivilegedHelperInstallSnapshot(helperToolExists: true, launchDaemonExists: false)
        let state = UsageMonitorState(
            report: nil,
            cacheSnapshot: nil,
            errorMessage: nil,
            privilegedHelperInstallSnapshot: snapshot
        )

        XCTAssertEqual(state.withRefreshing(true).privilegedHelperInstallSnapshot, snapshot)
    }

    func testRefreshingPreservesWeeklyUsageHistory() {
        let history = CodexUsageWeeklyHistory(samples: [
            Self.weeklySample(recordedAt: 1_000, remainingPercent: 92, resetsAt: 1_000 + 604_800)
        ])
        let state = UsageMonitorState(
            report: nil,
            cacheSnapshot: nil,
            weeklyUsageHistory: history,
            errorMessage: nil
        )

        XCTAssertEqual(state.withRefreshing(true).weeklyUsageHistory, history)
    }

    func testRefreshingPreservesResetWindowHistory() {
        let resetHistory = CodexUsageResetWindowHistory(records: [
            Self.resetWindowRecord(resetsAt: 1_800_604_800, finalUsedPercent: 74)
        ])
        let state = UsageMonitorState(
            report: nil,
            cacheSnapshot: nil,
            resetWindowHistory: resetHistory,
            errorMessage: nil
        )

        XCTAssertEqual(state.withRefreshing(true).resetWindowHistory, resetHistory)
    }

    func testCodexHistoryComparisonModelExposesPastWindowPickerAndModes() throws {
        let currentReset = 1_800_604_800
        let pastReset = currentReset - 604_800
        let olderPastReset = pastReset - 604_800
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 12, weeklyUsedPercent: 32, weeklyResetsAt: currentReset),
            cacheSnapshot: nil,
            resetWindowHistory: CodexUsageResetWindowHistory(records: [
                Self.resetWindowRecord(resetsAt: currentReset, finalUsedPercent: 32),
                Self.resetWindowRecord(resetsAt: pastReset, finalUsedPercent: 74),
                Self.resetWindowRecord(resetsAt: olderPastReset, finalUsedPercent: 51)
            ]),
            errorMessage: nil
        )

        let model = try XCTUnwrap(CodexUsageHistoryComparisonModel(state: state, calendar: Self.utcCalendar))

        XCTAssertEqual(model.availableModes, [.current, .past, .overlay])
        XCTAssertEqual(model.pastWindows.map(\.key.resetsAt), [pastReset, olderPastReset])
        XCTAssertEqual(model.defaultPastWindowKey?.resetsAt, pastReset)
        XCTAssertEqual(model.overlaySeries?.finalUsageMarker.usedPercent, 74)
    }

    func testCodexHistoryComparisonModelKeepsHistoryModesVisibleWithoutPastWindows() throws {
        let currentReset = 1_800_604_800
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 12, weeklyUsedPercent: 32, weeklyResetsAt: currentReset),
            cacheSnapshot: nil,
            resetWindowHistory: CodexUsageResetWindowHistory(records: [
                Self.resetWindowRecord(resetsAt: currentReset, finalUsedPercent: 32),
                Self.resetWindowRecord(resetsAt: currentReset + 1, finalUsedPercent: 32)
            ]),
            errorMessage: nil
        )

        let model = try XCTUnwrap(CodexUsageHistoryComparisonModel(state: state, calendar: Self.utcCalendar))

        XCTAssertEqual(model.availableModes, [.current, .past, .overlay])
        XCTAssertTrue(model.pastWindows.isEmpty)
        XCTAssertNil(model.defaultPastWindowKey)
        XCTAssertNil(model.overlaySeries)
    }

    func testCodexHistoryComparisonModelExcludesRollingCurrentResetDuplicates() throws {
        let currentReset = 1_800_604_800
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 12, weeklyUsedPercent: 1, weeklyResetsAt: currentReset),
            cacheSnapshot: nil,
            resetWindowHistory: CodexUsageResetWindowHistory(records: [
                Self.resetWindowRecord(resetsAt: currentReset - 9 * 60, finalUsedPercent: 0),
                Self.resetWindowRecord(resetsAt: currentReset - 2 * 60, finalUsedPercent: 1),
                Self.resetWindowRecord(resetsAt: currentReset, finalUsedPercent: 1)
            ]),
            errorMessage: nil
        )

        let model = try XCTUnwrap(CodexUsageHistoryComparisonModel(state: state, calendar: Self.utcCalendar))

        XCTAssertTrue(model.pastWindows.isEmpty)
        XCTAssertNil(model.defaultPastWindowKey)
        XCTAssertNil(model.overlaySeries)
    }

    func testCodexHistoryComparisonModelBackfillsPastWindowsFromWeeklyHistory() throws {
        let currentReset = 1_800_604_800
        let pastReset = currentReset - 604_800
        let pastStart = pastReset - 604_800
        let history = CodexUsageWeeklyHistory(samples: [
            Self.weeklySample(recordedAt: pastStart + 60 * 60, remainingPercent: 93, resetsAt: pastReset),
            Self.weeklySample(recordedAt: pastStart + 86_400 + 120, remainingPercent: 82, resetsAt: pastReset),
            Self.weeklySample(recordedAt: pastReset - 60, remainingPercent: 27, resetsAt: pastReset + 1),
            Self.weeklySample(recordedAt: currentReset - 2 * 86_400, remainingPercent: 100, resetsAt: currentReset)
        ])

        let model = try XCTUnwrap(CodexUsageHistoryComparisonModel(
            history: history,
            resetWindowHistory: .empty,
            weeklyWindow: Self.weeklyWindow(remainingPercent: 87, resetsAt: currentReset),
            currentReport: Self.report(fiveHourUsedPercent: 12, weeklyUsedPercent: 13, weeklyResetsAt: currentReset),
            currentTimestamp: currentReset - 60,
            calendar: Self.utcCalendar
        ))

        XCTAssertEqual(model.pastWindows.map(\.key.resetsAt), [pastReset])
        XCTAssertEqual(model.defaultPastWindowKey?.resetsAt, pastReset)
        XCTAssertEqual(model.overlaySeries?.finalUsageMarker.usedPercent, 73)
        XCTAssertEqual(model.resetWindowHistory.records.first?.source, .backfill)
    }

    func testCodexHistoryMarkerLabelShowsSevenDayEndUsage() throws {
        let recordedAt = Self.timestamp(year: 2026, month: 6, day: 25, hour: 6, minute: 28)
        let marker = CodexUsageResetWindowOverlayMarker(
            id: "codex-7",
            kind: .sevenDayEnd,
            day: 7,
            recordedAt: recordedAt,
            usedPercent: 74,
            remainingPercent: 26
        )

        XCTAssertEqual(
            CodexUsageHistoryMarkerLabel.hoverText(for: marker, calendar: Self.utcCalendar),
            "6/25 목 종료 · 26%"
        )
    }

    func testCodexHistoryPastTimelineLabelsUseActualDates() throws {
        let resetStart = Self.timestamp(year: 2026, month: 6, day: 18, hour: 6, minute: 28)
        let resetsAt = Self.timestamp(year: 2026, month: 6, day: 25, hour: 6, minute: 28)
        let record = CodexUsageResetWindowHistoryRecord(
            generatedAt: resetsAt - 60,
            limitId: "codex",
            windowDurationMins: 10_080,
            resetsAt: resetsAt,
            dailyEndSamples: [
                CodexUsageResetWindowDailySample(
                    dayIndex: 1,
                    recordedAt: resetStart + 86_400,
                    usedPercent: 20,
                    remainingPercent: 80
                )
            ],
            finalUsedPercent: 77,
            finalRemainingPercent: 23,
            sampleCount: 2,
            source: .backfill
        )
        let series = CodexUsageResetWindowOverlayBuilder().series(for: record)
        let window = CodexUsageResetWindowOverlayWindow(record: record)
        let firstDayMarker = try XCTUnwrap(series.dayEndMarkers.first)

        XCTAssertEqual(
            CodexUsageHistoryTimelineLabel.startLabel(for: series, calendar: Self.utcCalendar),
            "기록 시작 6/18 목 06:28"
        )
        XCTAssertEqual(
            CodexUsageHistoryTimelineLabel.endLabel(for: series, calendar: Self.utcCalendar),
            "6/25 목"
        )
        XCTAssertEqual(
            CodexUsageHistoryTimelineLabel.windowLabel(for: window, calendar: Self.utcCalendar),
            "6/18-6/25"
        )
        XCTAssertEqual(
            CodexUsageHistoryMarkerLabel.hoverText(for: firstDayMarker, calendar: Self.utcCalendar),
            "6/19 금 종료 · 80%"
        )
    }

    func testCodexHistoryModeLabelsDescribeComparisonIntent() {
        XCTAssertEqual(CodexUsageHistoryGraphMode.current.label, "현재")
        XCTAssertEqual(CodexUsageHistoryGraphMode.past.label, "지난")
        XCTAssertEqual(CodexUsageHistoryGraphMode.overlay.label, "비교")
    }

    func testSystemMetricsUpdateReplacesPrivilegedHelperInstallSnapshot() {
        let state = UsageMonitorState(report: nil, cacheSnapshot: nil, errorMessage: nil)
        let snapshot = PrivilegedHelperInstallSnapshot(helperToolExists: true, launchDaemonExists: true)
        let history = SystemMetricsHistory(samples: [
            SystemMetricsHistorySample(capturedAt: Date(timeIntervalSince1970: 1), cpuLoadPercent: 42, memoryUsedPercent: 55)
        ])

        let updated = state.withSystemMetrics(
            .unavailable,
            systemMetricsHistory: history,
            sleepPreventionStatus: .disabled,
            sleepPreventionTriggerStatus: .disabled,
            privilegedHelperInstallSnapshot: snapshot
        )

        XCTAssertEqual(updated.privilegedHelperInstallSnapshot, snapshot)
        XCTAssertEqual(updated.systemMetricsHistory, history)
    }

    func testEmptyStateDoesNotCaptureSystemMetrics() {
        let empty = UsageMonitorState.empty

        XCTAssertNil(empty.systemMetrics.cpuLoadPercent)
        XCTAssertNil(empty.systemMetrics.memoryUsedPercent)
        XCTAssertNil(empty.systemMetrics.networkReceivedRateBytesPerSecond)
        XCTAssertFalse(empty.systemMetrics.battery.isPresent)
    }

    func testSystemMetricsHistoryKeepsMostRecentSamples() {
        let start = Date(timeIntervalSince1970: 100)
        let totalSamples = SystemMetricsHistory.defaultMaxSamples + 5
        let history = (0..<totalSamples).reduce(SystemMetricsHistory.empty) { history, index in
            history.appending(
                Self.systemMetricsSnapshot(
                    capturedAt: start.addingTimeInterval(Double(index)),
                    cpuLoadPercent: Double(index),
                    memoryUsedPercent: Double(index + 10)
                )
            )
        }

        XCTAssertEqual(history.samples.count, SystemMetricsHistory.defaultMaxSamples)
        XCTAssertEqual(history.cpuLoadPercents.first, 5)
        XCTAssertEqual(history.cpuLoadPercents.last, Double(totalSamples - 1))
        XCTAssertEqual(history.memoryUsedPercents.first, 15)
        XCTAssertEqual(history.memoryUsedPercents.last, Double(totalSamples + 9))
    }

    func testSystemMetricsHistoryKeepsThreeMinuteTrendAtOneSecondCadence() {
        XCTAssertEqual(SystemMetricsHistory.defaultMaxSamples, 180)
    }

    func testSparklineScaleUsesAbsolutePercentScale() {
        let scale = SparklineScale(values: [49.0, 49.6])

        XCTAssertEqual(SparklineScale.lowerBound, 0, accuracy: 0.001)
        XCTAssertEqual(SparklineScale.upperBound, 100, accuracy: 0.001)
        XCTAssertEqual(scale.normalized(49.0), 0.49, accuracy: 0.001)
        XCTAssertEqual(scale.normalized(49.6), 0.496, accuracy: 0.001)
    }

    func testSparklineScaleKeepsWidePercentRangesStable() {
        let scale = SparklineScale(values: [0, 45, 100])

        XCTAssertEqual(SparklineScale.lowerBound, 0, accuracy: 0.001)
        XCTAssertEqual(SparklineScale.upperBound, 100, accuracy: 0.001)
        XCTAssertEqual(scale.normalized(45), 0.45, accuracy: 0.001)
    }

    func testWeeklyHistoryChartAnchorsResetAtHundredPercentAndMapsSamplesAcrossWeek() throws {
        let start = 1_800_000_000
        let reset = start + 604_800
        let history = CodexUsageWeeklyHistory(samples: [
            Self.weeklySample(recordedAt: start + 302_400, remainingPercent: 63, resetsAt: reset)
        ])
        let chart = WeeklyRemainingHistoryChart(
            history: history,
            weeklyWindow: Self.weeklyWindow(remainingPercent: 63, resetsAt: reset),
            calendar: Self.utcCalendar
        )

        XCTAssertEqual(chart.points.count, 2)
        XCTAssertEqual(chart.dayGridPositions.count, 8)
        XCTAssertEqual(chart.dayGridPositions.first, 0)
        XCTAssertEqual(chart.dayGridPositions.last, 1)
        XCTAssertEqual(chart.dayMarkers.count, 1)
        XCTAssertEqual(chart.points.first?.isResetAnchor, true)
        XCTAssertEqual(try XCTUnwrap(chart.points.first?.xPosition), 0, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(chart.points.first?.yPosition), 1, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(chart.latestActualPoint?.xPosition), 0.5, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(chart.latestActualPoint?.yPosition), 0.63, accuracy: 0.001)
        XCTAssertEqual(chart.summaryText, "63% 남음")
    }

    func testWeeklyHistoryChartShowsActualResetWeekdaysOnTimeline() throws {
        let calendar = Self.utcCalendar
        let resetDate = try XCTUnwrap(calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: 8,
            hour: 0,
            minute: 0
        )))
        let reset = Int(resetDate.timeIntervalSince1970)
        let chart = WeeklyRemainingHistoryChart(
            history: .empty,
            weeklyWindow: Self.weeklyWindow(remainingPercent: 94, resetsAt: reset),
            calendar: calendar
        )

        XCTAssertEqual(chart.resetStartLabel, "6/1 월")
        XCTAssertEqual(chart.resetEndLabel, "6/8 월")
    }

    func testWeeklyHistoryChartKeepsLastSampleForEachDayMarker() throws {
        let calendar = Self.utcCalendar
        let startDate = try XCTUnwrap(calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: 1,
            hour: 0,
            minute: 0
        )))
        let start = Int(startDate.timeIntervalSince1970)
        let reset = start + 604_800
        let history = CodexUsageWeeklyHistory(samples: [
            Self.weeklySample(recordedAt: start + 3_600, remainingPercent: 95, resetsAt: reset),
            Self.weeklySample(recordedAt: start + 82_800, remainingPercent: 88, resetsAt: reset),
            Self.weeklySample(recordedAt: start + 90_000, remainingPercent: 70, resetsAt: reset),
            Self.weeklySample(recordedAt: start + 560_000, remainingPercent: 41, resetsAt: reset)
        ])
        let chart = WeeklyRemainingHistoryChart(
            history: history,
            weeklyWindow: Self.weeklyWindow(remainingPercent: 41, resetsAt: reset),
            calendar: calendar
        )

        XCTAssertEqual(chart.dayMarkers.map(\.id), [0, 1, 6])
        XCTAssertEqual(chart.dayMarkers.map { UsageMonitorState.percent($0.point.remainingPercent) }, ["88", "70", "41"])
        XCTAssertEqual(chart.dayMarkers.first?.hoverLabel, "6/1 월 · 88%")
        XCTAssertEqual(chart.dayMarkers.last?.hoverLabel, "6/7 일 · 41%")
    }

    func testWeeklyHistoryChartFiltersPreviousResetWindow() {
        let start = 1_800_000_000
        let reset = start + 604_800
        let history = CodexUsageWeeklyHistory(samples: [
            Self.weeklySample(recordedAt: start - 120, remainingPercent: 20, resetsAt: reset - 604_800),
            Self.weeklySample(recordedAt: start + 60, remainingPercent: 99, resetsAt: reset)
        ])
        let chart = WeeklyRemainingHistoryChart(
            history: history,
            weeklyWindow: Self.weeklyWindow(remainingPercent: 99, resetsAt: reset)
        )

        XCTAssertEqual(chart.actualSampleCount, 1)
        XCTAssertEqual(chart.latestActualPoint?.remainingPercent, 99)
    }

    func testWeeklyHistoryChartKeepsSamplesWhenResetTimestampJittersBySeconds() {
        let start = 1_800_000_000
        let stableReset = start + 604_800
        let currentReset = stableReset - 1
        let history = CodexUsageWeeklyHistory(samples: [
            Self.weeklySample(recordedAt: start + 86_400 - 120, remainingPercent: 90, resetsAt: stableReset),
            Self.weeklySample(recordedAt: start + 2 * 86_400 - 120, remainingPercent: 80, resetsAt: stableReset),
            Self.weeklySample(recordedAt: start + 3 * 86_400 - 120, remainingPercent: 64, resetsAt: stableReset)
        ])
        let currentSample = Self.weeklySample(
            recordedAt: start + 3 * 86_400 + 120,
            remainingPercent: 63,
            resetsAt: currentReset
        )

        let chart = WeeklyRemainingHistoryChart(
            history: history,
            weeklyWindow: Self.weeklyWindow(remainingPercent: 63, resetsAt: currentReset),
            currentSample: currentSample
        )

        XCTAssertEqual(chart.actualSampleCount, 4)
        XCTAssertEqual(chart.latestActualPoint?.remainingPercent, 63)
        XCTAssertEqual(
            chart.dayMarkers.map { UsageMonitorState.percent($0.point.remainingPercent) },
            ["90", "80", "64", "63"]
        )
    }

    func testWeeklyHistoryChartStartsNewTimelineWhenResetTimestampChanges() throws {
        let calendar = Self.utcCalendar
        let oldStartDate = try XCTUnwrap(calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: 1,
            hour: 0
        )))
        let oldStart = Int(oldStartDate.timeIntervalSince1970)
        let oldReset = oldStart + 604_800
        let newStart = oldStart + 2 * 86_400
        let newReset = newStart + 604_800
        let currentSample = Self.weeklySample(recordedAt: newStart + 3_600, remainingPercent: 99, resetsAt: newReset)
        let history = CodexUsageWeeklyHistory(samples: [
            Self.weeklySample(recordedAt: oldStart + 86_400, remainingPercent: 82, resetsAt: oldReset),
            Self.weeklySample(recordedAt: oldStart + 2 * 86_400 - 60, remainingPercent: 74, resetsAt: oldReset)
        ])

        let chart = WeeklyRemainingHistoryChart(
            history: history,
            weeklyWindow: Self.weeklyWindow(remainingPercent: 99, resetsAt: newReset),
            currentSample: currentSample,
            calendar: calendar
        )

        XCTAssertEqual(chart.resetStartAt, newStart)
        XCTAssertEqual(chart.actualSampleCount, 1)
        XCTAssertEqual(chart.points.first?.recordedAt, newStart)
        XCTAssertEqual(chart.points.first?.remainingPercent, 100)
        XCTAssertEqual(chart.points.first?.xPosition, 0)
        XCTAssertEqual(chart.latestActualPoint?.remainingPercent, 99)
        XCTAssertEqual(chart.dayMarkers.map(\.hoverLabel), ["6/3 수 · 99%"])
        XCTAssertFalse(chart.points.contains { $0.recordedAt < newStart })
    }

    func testWeeklyHistoryChartDoesNotDrawUpwardRemainingSegmentsWithinSameResetWindow() {
        let start = 1_800_000_000
        let reset = start + 604_800
        let currentSample = Self.weeklySample(recordedAt: start + 18_000, remainingPercent: 85, resetsAt: reset)
        let history = CodexUsageWeeklyHistory(samples: [
            Self.weeklySample(recordedAt: start + 3_600, remainingPercent: 93, resetsAt: reset),
            Self.weeklySample(recordedAt: start + 7_200, remainingPercent: 88, resetsAt: reset),
            Self.weeklySample(recordedAt: start + 10_800, remainingPercent: 91, resetsAt: reset),
            Self.weeklySample(recordedAt: start + 14_400, remainingPercent: 80, resetsAt: reset)
        ])

        let chart = WeeklyRemainingHistoryChart(
            history: history,
            weeklyWindow: Self.weeklyWindow(remainingPercent: 85, resetsAt: reset),
            currentSample: currentSample
        )

        XCTAssertEqual(
            chart.points.map { UsageMonitorState.percent($0.remainingPercent) },
            ["100", "93", "88", "88", "80", "80"]
        )
        XCTAssertEqual(chart.latestActualPoint?.remainingPercent, 80)
        XCTAssertTrue(
            zip(chart.points, chart.points.dropFirst()).allSatisfy { previous, next in
                next.remainingPercent <= previous.remainingPercent
            },
            "Weekly remaining graph should never rise inside one reset window"
        )
    }

    func testWeeklyHistoryChartUsesCurrentSampleBeforePersistedHistoryCatchesUp() throws {
        let start = 1_800_000_000
        let reset = start + 604_800
        let currentSample = Self.weeklySample(recordedAt: start + 151_200, remainingPercent: 82, resetsAt: reset)

        let chart = WeeklyRemainingHistoryChart(
            history: .empty,
            weeklyWindow: Self.weeklyWindow(remainingPercent: 82, resetsAt: reset),
            currentSample: currentSample
        )

        XCTAssertEqual(chart.actualSampleCount, 1)
        XCTAssertEqual(try XCTUnwrap(chart.latestActualPoint?.xPosition), 0.25, accuracy: 0.001)
        XCTAssertEqual(chart.latestActualPoint?.remainingPercent, 82)
    }

    func testWeeklyHistoryChartShowsCompletedAndCurrentDayMarkers() throws {
        let calendar = Self.utcCalendar
        let startDate = try XCTUnwrap(calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: 1,
            hour: 0,
            minute: 0
        )))
        let start = Int(startDate.timeIntervalSince1970)
        let reset = start + 604_800
        let currentSample = Self.weeklySample(recordedAt: start + 2 * 86_400 + 10 * 3_600, remainingPercent: 66, resetsAt: reset)
        let history = CodexUsageWeeklyHistory(samples: [
            Self.weeklySample(recordedAt: start + 8 * 3_600, remainingPercent: 93, resetsAt: reset),
            Self.weeklySample(recordedAt: start + 23 * 3_600 + 50 * 60, remainingPercent: 88, resetsAt: reset),
            Self.weeklySample(recordedAt: start + 86_400 + 20 * 3_600, remainingPercent: 74, resetsAt: reset),
            Self.weeklySample(recordedAt: start + 2 * 86_400 + 9 * 3_600, remainingPercent: 68, resetsAt: reset)
        ])

        let chart = WeeklyRemainingHistoryChart(
            history: history,
            weeklyWindow: Self.weeklyWindow(remainingPercent: 66, resetsAt: reset),
            currentSample: currentSample,
            calendar: calendar
        )

        XCTAssertEqual(chart.dayMarkers.map(\.id), [0, 1, 2])
        XCTAssertEqual(chart.dayMarkers.map { UsageMonitorState.percent($0.point.remainingPercent) }, ["88", "74", "66"])
        XCTAssertEqual(chart.dayMarkers.first?.hoverLabel, "6/1 월 종료 · 88%")
        XCTAssertEqual(chart.dayMarkers[1].hoverLabel, "6/2 화 종료 · 74%")
        XCTAssertEqual(chart.dayMarkers.last?.hoverLabel, "6/3 수 · 66%")
        XCTAssertEqual(chart.latestActualPoint?.remainingPercent, 66)
    }

    func testWeeklyHistoryChartCarriesForwardCompletedDayMarkersAcrossResetBoundary() throws {
        let calendar = Self.utcCalendar
        let startDate = try XCTUnwrap(calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: 1,
            hour: 0,
            minute: 21,
            second: 23
        )))
        let start = Int(startDate.timeIntervalSince1970)
        let reset = start + 604_800
        let history = CodexUsageWeeklyHistory(samples: [
            Self.weeklySample(recordedAt: start + 86_400 + 18 * 3_600, remainingPercent: 87, resetsAt: reset),
            Self.weeklySample(recordedAt: start + 2 * 86_400 - 5 * 60, remainingPercent: 83, resetsAt: reset),
            Self.weeklySample(recordedAt: start + 2 * 86_400 + 17 * 3_600, remainingPercent: 64, resetsAt: reset)
        ])
        let currentSample = Self.weeklySample(
            recordedAt: start + 2 * 86_400 + 17 * 3_600 + 2 * 60,
            remainingPercent: 64,
            resetsAt: reset
        )

        let chart = WeeklyRemainingHistoryChart(
            history: history,
            weeklyWindow: Self.weeklyWindow(remainingPercent: 64, resetsAt: reset),
            currentSample: currentSample,
            calendar: calendar
        )

        XCTAssertEqual(chart.dayMarkers.map(\.id), [0, 1, 2])
        XCTAssertEqual(chart.dayMarkers.map(\.hoverLabel), ["6/1 월 종료 · 100%", "6/2 화 종료 · 83%", "6/3 수 · 64%"])
        XCTAssertEqual(chart.recordingStartLabel, "기록 시작 6/2 화 18:21")
        XCTAssertEqual(chart.timelineStartDisplayLabel, "기록 시작 6/2 화 18:21")
        XCTAssertEqual(chart.dayMarkers[0].point.recordedAt, start + 86_400)
        XCTAssertEqual(chart.dayMarkers[1].point.recordedAt, start + 2 * 86_400)
        XCTAssertEqual(chart.dayMarkers[2].point.recordedAt, currentSample.recordedAt)
        XCTAssertEqual(try XCTUnwrap(chart.dayMarkers[0].point.xPosition), 1.0 / 7.0, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(chart.dayMarkers[1].point.xPosition), 2.0 / 7.0, accuracy: 0.001)
        XCTAssertEqual(chart.latestActualPoint?.remainingPercent, 64)
        XCTAssertEqual(chart.points.last, chart.latestActualPoint)
        XCTAssertEqual(chart.points.map(\.xPosition), chart.points.map(\.xPosition).sorted())
        XCTAssertFalse(chart.points.contains { $0.recordedAt > currentSample.recordedAt })
    }

    func testWeeklyHistoryChartStartsAtHundredPercentWithoutExtendingPastCurrentSample() {
        let start = 1_800_000_000
        let reset = start + 604_800
        let currentSample = Self.weeklySample(recordedAt: start + 2 * 86_400 + 10 * 3_600, remainingPercent: 66, resetsAt: reset)

        let chart = WeeklyRemainingHistoryChart(
            history: .empty,
            weeklyWindow: Self.weeklyWindow(remainingPercent: 66, resetsAt: reset),
            currentSample: currentSample
        )

        XCTAssertEqual(chart.points.first?.isResetAnchor, true)
        XCTAssertEqual(chart.points.first?.remainingPercent, 100)
        XCTAssertEqual(chart.points.last, chart.latestActualPoint)
        XCTAssertEqual(chart.points.last?.remainingPercent, 66)
        XCTAssertFalse(chart.points.contains { $0.recordedAt > currentSample.recordedAt })
    }

    func testWeeklyHistoryHoverLabelAvoidsCurrentPercentLabelWhenMarkersAreClose() {
        let size = CGSize(width: 244, height: 74)
        let mondayMarker = CGPoint(x: 36, y: 12)
        let currentMarker = CGPoint(x: 70, y: 12)
        let currentLabel = WeeklyRemainingHistoryLabelPlacement.valueLabelPosition(
            for: currentMarker,
            in: size
        )
        let hoverLabel = WeeklyRemainingHistoryLabelPlacement.hoverLabelPosition(
            for: mondayMarker,
            avoiding: currentLabel,
            in: size
        )

        let currentRect = WeeklyRemainingHistoryLabelPlacement.labelRect(
            center: currentLabel,
            size: WeeklyRemainingHistoryLabelPlacement.valueLabelSize
        )
        let hoverRect = WeeklyRemainingHistoryLabelPlacement.labelRect(
            center: hoverLabel,
            size: WeeklyRemainingHistoryLabelPlacement.hoverLabelSize
        )

        XCTAssertFalse(
            hoverRect.intersects(currentRect.insetBy(dx: -4, dy: -3)),
            "Hover tooltip should not cover the current percent label for adjacent weekday markers"
        )
    }

    func testWeeklyHistoryMarkerHitTestingUsesTouchFriendlyRadius() {
        let size = CGSize(width: 244, height: 74)
        let marker = WeeklyRemainingHistoryDayMarker(
            id: 1,
            point: WeeklyRemainingHistoryPoint(
                recordedAt: 1_800_000_000,
                remainingPercent: 83,
                xPosition: 0.25,
                isResetAnchor: false
            ),
            hoverLabel: "6/2 화 · 83%"
        )
        let markerPoint = WeeklyRemainingHistoryInteraction.point(for: marker.point, in: size)

        XCTAssertEqual(
            WeeklyRemainingHistoryInteraction.nearestMarkerID(
                to: CGPoint(x: markerPoint.x + 18, y: markerPoint.y),
                markers: [marker],
                in: size
            ),
            1
        )
        XCTAssertNil(
            WeeklyRemainingHistoryInteraction.nearestMarkerID(
                to: CGPoint(x: markerPoint.x + 30, y: markerPoint.y),
                markers: [marker],
                in: size
            )
        )
    }

    func testWeeklyHistoryLineIncludesCurrentMarkerPoint() {
        let start = 1_800_000_000
        let reset = start + 604_800
        let currentSample = Self.weeklySample(
            recordedAt: start + 4 * 86_400 + 12 * 3_600,
            remainingPercent: 58,
            resetsAt: reset
        )
        let history = CodexUsageWeeklyHistory(samples: [
            Self.weeklySample(recordedAt: start + 2 * 86_400, remainingPercent: 83, resetsAt: reset),
            Self.weeklySample(recordedAt: start + 3 * 86_400, remainingPercent: 74, resetsAt: reset),
            currentSample
        ])

        let chart = WeeklyRemainingHistoryChart(
            history: history,
            weeklyWindow: Self.weeklyWindow(remainingPercent: 58, resetsAt: reset),
            currentSample: currentSample
        )

        XCTAssertEqual(chart.points.last, chart.latestActualPoint)
        XCTAssertEqual(chart.points.last?.recordedAt, currentSample.recordedAt)
        XCTAssertEqual(chart.points.last?.remainingPercent, 58)
    }

    func testMacResourcesTabStaysUnscrollableWithTrendGraphs() {
        XCTAssertFalse(MacDogPopoverModule.codex.usesScrollableContent)
        XCTAssertFalse(MacDogPopoverModule.mac.usesScrollableContent)
        XCTAssertFalse(MacDogPopoverModule.sleep.usesScrollableContent)
        XCTAssertFalse(MacDogPopoverModule.battery.usesScrollableContent)
        XCTAssertTrue(MacDogPopoverModule.settings.usesScrollableContent)
        XCTAssertGreaterThan(CodexUsagePanelLayout.weeklyGraphHeight, 0)
        XCTAssertLessThanOrEqual(CodexUsagePanelLayout.weeklyGraphHeight, 90)
        XCTAssertEqual(CodexUsagePanelLayout.weeklyGraphYAxisWidth, 28)
        XCTAssertEqual(CodexUsagePanelLayout.weeklyGraphAxisSpacing, 5)
        XCTAssertEqual(
            CodexUsagePanelLayout.weeklyGraphPlotStartX,
            CodexUsagePanelLayout.weeklyGraphYAxisWidth + CodexUsagePanelLayout.weeklyGraphAxisSpacing
        )
        XCTAssertEqual(CodexUsagePanelLayout.weeklyGraphTimelineHeight, 13)
        XCTAssertGreaterThan(MacResourcesPanelLayout.sparklineHeight, 0)
        XCTAssertLessThanOrEqual(
            MacResourcesPanelLayout.estimatedContentHeight,
            MacDogPopoverLayout.nonScrollableContentHeight
        )
    }

    func testWeeklyTimelineStartLabelStaysInsideGraphBounds() {
        let totalWidth = MacDogPopoverLayout.contentSurfaceSize.width - (MacDogPopoverLayout.contentPadding * 2)
        let startLabelWidth = WeeklyRemainingTimelineLabelLayout.startLabelWidth(totalWidth: totalWidth)

        XCTAssertGreaterThan(startLabelWidth, 150)
        XCTAssertLessThanOrEqual(
            WeeklyRemainingTimelineLabelLayout.leadingInset +
                startLabelWidth +
                WeeklyRemainingTimelineLabelLayout.labelSpacing +
                WeeklyRemainingTimelineLabelLayout.endLabelWidth,
            totalWidth
        )
    }

    func testDemoDataProvidesCpuAndMemoryTrendSamplesForMacTab() {
        let state = MacDogDemoData.state()

        XCTAssertGreaterThan(state.systemMetricsHistory.cpuLoadPercents.count, 1)
        XCTAssertGreaterThan(state.systemMetricsHistory.memoryUsedPercents.count, 1)
        XCTAssertEqual(state.systemMetricsHistory.cpuLoadPercents.last, state.systemMetrics.cpuLoadPercent)
        XCTAssertEqual(state.systemMetricsHistory.memoryUsedPercents.last, state.systemMetrics.memoryUsedPercent)
    }

    func testDemoDataProvidesWeeklyUsageHistoryForCodexTab() {
        let state = MacDogDemoData.state(now: MacDogDemoData.readmeScreenshotTimestamp)
        let chart = WeeklyRemainingHistoryChart(
            history: state.weeklyUsageHistory,
            weeklyWindow: state.codexLimit?.weekly,
            calendar: Self.utcCalendar
        )

        XCTAssertGreaterThan(chart.actualSampleCount, 1)
        XCTAssertEqual(chart.latestActualPoint?.remainingPercent, state.codexLimit?.weekly?.remainingPercent)
        XCTAssertEqual(chart.resetStartLabel, "6/1 월")
        XCTAssertEqual(chart.resetEndLabel, "6/8 월")
    }

    func testPetReactionPrioritizesSystemLoad() {
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 10, weeklyUsedPercent: 20),
            cacheSnapshot: nil,
            errorMessage: nil,
            systemMetrics: Self.systemMetricsSnapshot(
                capturedAt: Date(timeIntervalSince1970: 100),
                cpuLoadPercent: 88,
                memoryUsedPercent: 40,
                battery: Self.battery(percent: 12, isCharging: false, isConnectedToPower: false)
            )
        )

        XCTAssertEqual(state.petReaction, .systemLoad)
        XCTAssertTrue(state.petReaction.pausesRoaming)
    }

    func testPetReactionUsesLowBatteryOnlyWhenUnplugged() {
        let unplugged = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 10, weeklyUsedPercent: 20),
            cacheSnapshot: nil,
            errorMessage: nil,
            systemMetrics: Self.systemMetricsSnapshot(
                capturedAt: Date(timeIntervalSince1970: 100),
                cpuLoadPercent: 20,
                memoryUsedPercent: 40,
                battery: Self.battery(percent: 18, isCharging: false, isConnectedToPower: false)
            )
        )
        let plugged = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 10, weeklyUsedPercent: 20),
            cacheSnapshot: nil,
            errorMessage: nil,
            systemMetrics: Self.systemMetricsSnapshot(
                capturedAt: Date(timeIntervalSince1970: 100),
                cpuLoadPercent: 20,
                memoryUsedPercent: 40,
                battery: Self.battery(percent: 18, isCharging: false, isConnectedToPower: true)
            )
        )

        XCTAssertEqual(unplugged.petReaction, .lowBattery)
        XCTAssertEqual(plugged.petReaction, .normal)
    }

    func testPetReactionShowsChargingState() {
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 10, weeklyUsedPercent: 20),
            cacheSnapshot: nil,
            errorMessage: nil,
            systemMetrics: Self.systemMetricsSnapshot(
                capturedAt: Date(timeIntervalSince1970: 100),
                cpuLoadPercent: 20,
                memoryUsedPercent: 40,
                battery: Self.battery(percent: 62, isCharging: true, isConnectedToPower: true)
            )
        )

        XCTAssertEqual(state.petReaction, .charging)
        XCTAssertTrue(state.petReaction.pausesRoaming)
    }

    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func report(
        fiveHourUsedPercent: Double,
        weeklyUsedPercent: Double,
        fiveHourResetsAt: Int? = nil,
        weeklyResetsAt: Int? = nil,
        rateLimitReachedType: String? = nil
    ) -> CodexUsageReport {
        let fiveHour = UsageWindowReport(
            kind: .fiveHour,
            usedPercent: fiveHourUsedPercent,
            remainingPercent: 100 - fiveHourUsedPercent,
            windowDurationMins: 300,
            resetsAt: fiveHourResetsAt
        )
        let weekly = UsageWindowReport(
            kind: .weekly,
            usedPercent: weeklyUsedPercent,
            remainingPercent: 100 - weeklyUsedPercent,
            windowDurationMins: 10_080,
            resetsAt: weeklyResetsAt
        )
        let limit = UsageLimitReport(
            limitId: "codex",
            limitName: "Codex",
            primary: fiveHour,
            secondary: weekly,
            credits: nil,
            planType: "pro",
            rateLimitReachedType: rateLimitReachedType
        )
        return CodexUsageReport(
            generatedAt: 0,
            source: "test",
            planType: "pro",
            credits: nil,
            rateLimitReachedType: rateLimitReachedType,
            limits: ["codex": limit]
        )
    }

    private static func incompleteCodexReport() -> CodexUsageReport {
        let limit = UsageLimitReport(
            limitId: "codex",
            limitName: "Codex",
            primary: UsageWindowReport(
                kind: .other,
                usedPercent: 0,
                remainingPercent: 100,
                windowDurationMins: nil,
                resetsAt: nil
            ),
            secondary: nil,
            credits: nil,
            planType: "pro",
            rateLimitReachedType: nil
        )
        return CodexUsageReport(
            generatedAt: 0,
            source: "test",
            planType: "pro",
            credits: nil,
            rateLimitReachedType: nil,
            limits: ["codex": limit]
        )
    }

    private static func weeklyWindow(
        remainingPercent: Double,
        resetsAt: Int
    ) -> UsageWindowReport {
        UsageWindowReport(
            kind: .weekly,
            usedPercent: 100 - remainingPercent,
            remainingPercent: remainingPercent,
            windowDurationMins: 10_080,
            resetsAt: resetsAt
        )
    }

    private static func weeklySample(
        recordedAt: Int,
        remainingPercent: Double,
        resetsAt: Int
    ) -> CodexUsageWeeklyHistorySample {
        CodexUsageWeeklyHistorySample(
            recordedAt: recordedAt,
            usedPercent: 100 - remainingPercent,
            remainingPercent: remainingPercent,
            resetsAt: resetsAt,
            windowDurationMins: 10_080
        )
    }

    private static func timestamp(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0
    ) -> Int {
        let date = utcCalendar.date(from: DateComponents(
            timeZone: TimeZone(secondsFromGMT: 0),
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
        return Int(date.timeIntervalSince1970)
    }

    private static func resetWindowRecord(
        resetsAt: Int,
        finalUsedPercent: Double
    ) -> CodexUsageResetWindowHistoryRecord {
        CodexUsageResetWindowHistoryRecord(
            generatedAt: resetsAt - 60,
            limitId: "codex",
            windowDurationMins: 10_080,
            resetsAt: resetsAt,
            dailyEndSamples: [
                CodexUsageResetWindowDailySample(
                    dayIndex: 7,
                    recordedAt: resetsAt,
                    usedPercent: finalUsedPercent,
                    remainingPercent: 100 - finalUsedPercent
                )
            ],
            finalUsedPercent: finalUsedPercent,
            finalRemainingPercent: 100 - finalUsedPercent,
            sampleCount: 1,
            source: .liveCache
        )
    }

    private static func systemMetricsSnapshot(
        capturedAt: Date,
        cpuLoadPercent: Double,
        memoryUsedPercent: Double,
        battery: BatteryStatusSnapshot = .unavailable
    ) -> SystemMetricsSnapshot {
        SystemMetricsSnapshot(
            capturedAt: capturedAt,
            cpuLoadPercent: cpuLoadPercent,
            memoryUsedPercent: memoryUsedPercent,
            memoryDetails: nil,
            diskUsedPercent: nil,
            diskDetails: nil,
            networkReceivedBytes: nil,
            networkSentBytes: nil,
            networkReceivedRateBytesPerSecond: nil,
            networkSentRateBytesPerSecond: nil,
            activeInterfaceCount: 0,
            primaryNetworkInterfaceName: nil,
            localIPAddress: nil,
            cpuBreakdown: nil,
            battery: battery,
            chargeLimitSupport: .unavailable
        )
    }

    private static func battery(
        percent: Int,
        isCharging: Bool,
        isConnectedToPower: Bool
    ) -> BatteryStatusSnapshot {
        BatteryStatusSnapshot(
            isPresent: true,
            percent: percent,
            isCharging: isCharging,
            isCharged: false,
            isConnectedToPower: isConnectedToPower,
            timeToFullChargeMinutes: nil,
            timeToEmptyMinutes: nil,
            cycleCount: nil,
            temperatureCelsius: nil
        )
    }
}
