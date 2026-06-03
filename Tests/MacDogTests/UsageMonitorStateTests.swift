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

    func testMacResourcesTabStaysUnscrollableWithTrendGraphs() {
        XCTAssertFalse(MacDogPopoverModule.codex.usesScrollableContent)
        XCTAssertFalse(MacDogPopoverModule.mac.usesScrollableContent)
        XCTAssertFalse(MacDogPopoverModule.sleep.usesScrollableContent)
        XCTAssertFalse(MacDogPopoverModule.battery.usesScrollableContent)
        XCTAssertFalse(MacDogPopoverModule.settings.usesScrollableContent)
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

    private static func report(fiveHourUsedPercent: Double, weeklyUsedPercent: Double) -> CodexUsageReport {
        let fiveHour = UsageWindowReport(
            kind: .fiveHour,
            usedPercent: fiveHourUsedPercent,
            remainingPercent: 100 - fiveHourUsedPercent,
            windowDurationMins: 300,
            resetsAt: nil
        )
        let weekly = UsageWindowReport(
            kind: .weekly,
            usedPercent: weeklyUsedPercent,
            remainingPercent: 100 - weeklyUsedPercent,
            windowDurationMins: 10_080,
            resetsAt: nil
        )
        let limit = UsageLimitReport(
            limitId: "codex",
            limitName: "Codex",
            primary: fiveHour,
            secondary: weekly,
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
