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

    func testSystemMetricsHistoryKeepsMostRecentSamples() {
        let start = Date(timeIntervalSince1970: 100)
        let history = (0..<65).reduce(SystemMetricsHistory.empty) { history, index in
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
        XCTAssertEqual(history.cpuLoadPercents.last, 64)
        XCTAssertEqual(history.memoryUsedPercents.first, 15)
        XCTAssertEqual(history.memoryUsedPercents.last, 74)
    }

    func testMacResourcesTabStaysUnscrollableWithTrendGraphs() {
        XCTAssertFalse(MacDogPopoverModule.codex.usesScrollableContent)
        XCTAssertFalse(MacDogPopoverModule.mac.usesScrollableContent)
        XCTAssertTrue(MacDogPopoverModule.sleep.usesScrollableContent)
        XCTAssertFalse(MacDogPopoverModule.battery.usesScrollableContent)
    }

    func testDemoDataProvidesCpuAndMemoryTrendSamplesForMacTab() {
        let state = MacDogDemoData.state()

        XCTAssertGreaterThan(state.systemMetricsHistory.cpuLoadPercents.count, 1)
        XCTAssertGreaterThan(state.systemMetricsHistory.memoryUsedPercents.count, 1)
        XCTAssertEqual(state.systemMetricsHistory.cpuLoadPercents.last, state.systemMetrics.cpuLoadPercent)
        XCTAssertEqual(state.systemMetricsHistory.memoryUsedPercents.last, state.systemMetrics.memoryUsedPercent)
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

    private static func systemMetricsSnapshot(
        capturedAt: Date,
        cpuLoadPercent: Double,
        memoryUsedPercent: Double
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
            battery: .unavailable,
            chargeLimitSupport: .unavailable
        )
    }
}
