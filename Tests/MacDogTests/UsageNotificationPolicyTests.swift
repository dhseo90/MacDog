import XCTest
import CodexUsageCore
@testable import MacDog

final class UsageNotificationPolicyTests: XCTestCase {
    func testPolicyCreatesStrongestThresholdEventForEachUsageWindow() {
        let reset = 1_800_003_600
        let state = Self.state(
            fiveHourUsedPercent: 82,
            fiveHourResetsAt: reset,
            weeklyUsedPercent: 96,
            weeklyResetsAt: reset + 604_800
        )

        let candidates = UsageNotificationPolicy().candidates(
            for: state,
            now: Date(timeIntervalSince1970: 1_800_000_000)
        )

        XCTAssertEqual(candidates.map(\.event), [.highUsage, .approachingLimit])
        XCTAssertEqual(candidates.map(\.window), [.fiveHour, .weekly])
        XCTAssertEqual(candidates.map(\.usedPercent), [82, 96])
        XCTAssertEqual(candidates.map(\.dedupeKey.rawValue), [
            "usage.highUsage.fiveHour.reset.1800003600",
            "usage.approachingLimit.weekly.reset.1800608400"
        ])
    }

    func testPolicyCreatesLimitEventFromReachedTypeWithoutChangingUsageSchema() {
        let state = Self.state(
            fiveHourUsedPercent: 72,
            fiveHourResetsAt: 1_800_003_600,
            weeklyUsedPercent: 64,
            weeklyResetsAt: 1_800_604_800,
            rateLimitReachedType: "primary"
        )

        let candidates = UsageNotificationPolicy().candidates(
            for: state,
            now: Date(timeIntervalSince1970: 1_800_000_000)
        )

        XCTAssertEqual(candidates.map(\.event), [.limitReached])
        XCTAssertEqual(candidates.first?.window, .fiveHour)
        XCTAssertEqual(candidates.first?.dedupeKey.rawValue, "usage.limitReached.fiveHour.reset.1800003600")
    }

    func testPolicyCreatesResetSoonOnlyForHighUsageWindowsInsideLeadTime() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let state = Self.state(
            fiveHourUsedPercent: 81,
            fiveHourResetsAt: 1_800_001_800,
            weeklyUsedPercent: 79,
            weeklyResetsAt: 1_800_001_800
        )

        let candidates = UsageNotificationPolicy().candidates(for: state, now: now)

        XCTAssertEqual(candidates.map(\.event), [.highUsage, .resetSoon])
        XCTAssertEqual(candidates.map(\.window), [.fiveHour, .fiveHour])
        XCTAssertEqual(candidates.map(\.dedupeKey.rawValue), [
            "usage.highUsage.fiveHour.reset.1800001800",
            "usage.resetSoon.fiveHour.reset.1800001800"
        ])
    }

    func testDedupeLedgerAllowsEachEventOncePerWindowResetBoundary() {
        let firstReset = UsageNotificationDedupeKey(
            event: .highUsage,
            window: .fiveHour,
            resetsAt: 1_800_003_600
        )
        let sameResetDifferentEvent = UsageNotificationDedupeKey(
            event: .approachingLimit,
            window: .fiveHour,
            resetsAt: 1_800_003_600
        )
        let nextResetSameEvent = UsageNotificationDedupeKey(
            event: .highUsage,
            window: .fiveHour,
            resetsAt: 1_800_021_600
        )
        let ledger = UsageNotificationDedupeLedger(deliveredKeys: [firstReset])

        XCTAssertEqual(
            ledger.newKeys([firstReset, sameResetDifferentEvent, nextResetSameEvent]),
            [sameResetDifferentEvent, nextResetSameEvent]
        )
        XCTAssertEqual(
            ledger.recording([sameResetDifferentEvent]).deliveredKeys,
            [firstReset, sameResetDifferentEvent]
        )
    }

    func testPolicyCreatesDailyAndCumulativePacemakerEventsForCurrentDay() throws {
        let resetStartAt = 1_800_000_000
        let recordedAt = resetStartAt + 2 * 86_400 + 3_600
        let resetsAt = resetStartAt + 7 * 86_400
        let report = Self.report(
            fiveHourUsedPercent: 20,
            fiveHourResetsAt: recordedAt + 3_600,
            weeklyUsedPercent: 44,
            weeklyResetsAt: resetsAt,
            rateLimitReachedType: nil
        )
        let state = UsageMonitorState(
            report: report,
            cacheSnapshot: CodexUsageCacheSnapshot(
                cachedAt: recordedAt,
                staleAfterSeconds: 120,
                report: report,
                error: nil
            ),
            weeklyUsageHistory: CodexUsageWeeklyHistory(samples: [
                CodexUsageWeeklyHistorySample(
                    recordedAt: resetStartAt + 2 * 86_400 - 60,
                    usedPercent: 25,
                    remainingPercent: 75,
                    resetsAt: resetsAt,
                    windowDurationMins: 10_080
                )
            ]),
            errorMessage: nil,
            runnerEvaluationDate: Date(timeIntervalSince1970: TimeInterval(recordedAt))
        )

        let candidates = UsageNotificationPolicy().candidates(
            for: state,
            now: Date(timeIntervalSince1970: TimeInterval(recordedAt))
        )

        XCTAssertEqual(candidates.map(\.event), [.dailyTargetExceeded, .cumulativePaceExceeded])
        XCTAssertEqual(candidates.map(\.dedupeKey.rawValue), [
            "usage.dailyTargetExceeded.weekly.reset.1800604800.day.3",
            "usage.cumulativePaceExceeded.weekly.reset.1800604800.day.3"
        ])
    }

    func testPolicyCreatesDailyApproachingEventWithoutBaselineGuessing() {
        let resetStartAt = 1_800_000_000
        let recordedAt = resetStartAt + 2 * 86_400 + 3_600
        let resetsAt = resetStartAt + 7 * 86_400
        let report = Self.report(
            fiveHourUsedPercent: 20,
            fiveHourResetsAt: recordedAt + 3_600,
            weeklyUsedPercent: 35,
            weeklyResetsAt: resetsAt,
            rateLimitReachedType: nil
        )
        let snapshot = CodexUsageCacheSnapshot(
            cachedAt: recordedAt,
            staleAfterSeconds: 120,
            report: report,
            error: nil
        )
        let boundarySample = CodexUsageWeeklyHistorySample(
            recordedAt: resetStartAt + 2 * 86_400 - 60,
            usedPercent: 23,
            remainingPercent: 77,
            resetsAt: resetsAt,
            windowDurationMins: 10_080
        )
        let available = UsageMonitorState(
            report: report,
            cacheSnapshot: snapshot,
            weeklyUsageHistory: CodexUsageWeeklyHistory(samples: [boundarySample]),
            errorMessage: nil
        )
        let missingBaseline = UsageMonitorState(
            report: report,
            cacheSnapshot: snapshot,
            weeklyUsageHistory: .empty,
            errorMessage: nil
        )

        XCTAssertEqual(
            UsageNotificationPolicy().candidates(for: available).map(\.event),
            [.dailyTargetApproaching]
        )
        XCTAssertTrue(UsageNotificationPolicy().candidates(for: missingBaseline).isEmpty)
    }

    private static func state(
        fiveHourUsedPercent: Double,
        fiveHourResetsAt: Int?,
        weeklyUsedPercent: Double,
        weeklyResetsAt: Int?,
        rateLimitReachedType: String? = nil
    ) -> UsageMonitorState {
        UsageMonitorState(
            report: report(
                fiveHourUsedPercent: fiveHourUsedPercent,
                fiveHourResetsAt: fiveHourResetsAt,
                weeklyUsedPercent: weeklyUsedPercent,
                weeklyResetsAt: weeklyResetsAt,
                rateLimitReachedType: rateLimitReachedType
            ),
            cacheSnapshot: nil,
            errorMessage: nil
        )
    }

    private static func report(
        fiveHourUsedPercent: Double,
        fiveHourResetsAt: Int?,
        weeklyUsedPercent: Double,
        weeklyResetsAt: Int?,
        rateLimitReachedType: String?
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
}
