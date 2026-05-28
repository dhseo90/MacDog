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

        let updated = state.withSystemMetrics(
            .unavailable,
            sleepPreventionStatus: .disabled,
            sleepPreventionTriggerStatus: .disabled,
            privilegedHelperInstallSnapshot: snapshot
        )

        XCTAssertEqual(updated.privilegedHelperInstallSnapshot, snapshot)
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
}
