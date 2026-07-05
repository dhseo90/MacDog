import XCTest
@testable import CodexUsageCore

final class CodexUsageSessionPlanTests: XCTestCase {
    func testOneHourPlanIsSafeWhenProjectedUsageStaysBelowEightyPercent() throws {
        let now = 1_800_000_000
        let resetsAt = now + 3 * 60 * 60
        let previous = Self.weeklySample(
            recordedAt: now - 60 * 60,
            usedPercent: 35,
            resetsAt: resetsAt
        )
        let snapshot = Self.snapshot(
            cachedAt: now,
            staleAfterSeconds: 120,
            report: Self.report(weeklyUsedPercent: 40, weeklyResetsAt: resetsAt)
        )

        let result = CodexUsageSessionPlanBuilder().plan(
            duration: .oneHour,
            snapshot: snapshot,
            weeklyHistory: CodexUsageWeeklyHistory(samples: [previous]),
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(result.duration, .oneHour)
        XCTAssertEqual(result.durationSeconds, 3_600)
        XCTAssertEqual(result.state, .safe)
        XCTAssertEqual(result.currentUsedPercent, 40)
        XCTAssertEqual(try XCTUnwrap(result.projectedUsedPercent), 45, accuracy: 0.0001)
        XCTAssertEqual(result.sampleCount, 2)
        XCTAssertEqual(result.title, "1시간 작업 여유")
    }

    func testOneHourPlanWarnsWhenProjectedUsageReachesEightyPercent() throws {
        let now = 1_800_000_000
        let resetsAt = now + 3 * 60 * 60
        let previous = Self.weeklySample(
            recordedAt: now - 60 * 60,
            usedPercent: 73,
            resetsAt: resetsAt
        )
        let snapshot = Self.snapshot(
            cachedAt: now,
            staleAfterSeconds: 120,
            report: Self.report(weeklyUsedPercent: 78, weeklyResetsAt: resetsAt)
        )

        let result = CodexUsageSessionPlanBuilder().plan(
            duration: .oneHour,
            snapshot: snapshot,
            weeklyHistory: CodexUsageWeeklyHistory(samples: [previous]),
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(result.state, .watch)
        XCTAssertEqual(result.durationSeconds, 3_600)
        XCTAssertEqual(try XCTUnwrap(result.projectedUsedPercent), 83, accuracy: 0.0001)
        XCTAssertEqual(result.title, "1시간 작업 주의")
    }

    func testOneHourPlanIsRiskyWhenProjectedUsageReachesNinetyFivePercent() throws {
        let now = 1_800_000_000
        let resetsAt = now + 3 * 60 * 60
        let previous = Self.weeklySample(
            recordedAt: now - 60 * 60,
            usedPercent: 89,
            resetsAt: resetsAt
        )
        let snapshot = Self.snapshot(
            cachedAt: now,
            staleAfterSeconds: 120,
            report: Self.report(weeklyUsedPercent: 94, weeklyResetsAt: resetsAt)
        )

        let result = CodexUsageSessionPlanBuilder().plan(
            duration: .oneHour,
            snapshot: snapshot,
            weeklyHistory: CodexUsageWeeklyHistory(samples: [previous]),
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(result.state, .risky)
        XCTAssertEqual(result.durationSeconds, 3_600)
        XCTAssertEqual(try XCTUnwrap(result.projectedUsedPercent), 99, accuracy: 0.0001)
        XCTAssertEqual(result.title, "1시간 작업 위험")
    }

    func testUntilResetPlanUsesProjectionRemainingSeconds() throws {
        let now = 1_800_000_000
        let resetsAt = now + 2 * 60 * 60
        let previous = Self.weeklySample(
            recordedAt: now - 60 * 60,
            usedPercent: 45,
            resetsAt: resetsAt
        )
        let snapshot = Self.snapshot(
            cachedAt: now,
            staleAfterSeconds: 120,
            report: Self.report(weeklyUsedPercent: 50, weeklyResetsAt: resetsAt)
        )

        let result = CodexUsageSessionPlanBuilder().plan(
            duration: .untilReset,
            snapshot: snapshot,
            weeklyHistory: CodexUsageWeeklyHistory(samples: [previous]),
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(result.duration, .untilReset)
        XCTAssertEqual(result.durationSeconds, 7_200)
        XCTAssertEqual(result.state, .safe)
        XCTAssertEqual(try XCTUnwrap(result.projectedUsedPercent), 60, accuracy: 0.0001)
    }

    func testStaleSnapshotReturnsUnavailablePlan() {
        let now = 1_800_000_000
        let snapshot = Self.snapshot(
            cachedAt: now - 300,
            staleAfterSeconds: 120,
            report: Self.report(weeklyUsedPercent: 50, weeklyResetsAt: now + 2 * 60 * 60)
        )

        let result = CodexUsageSessionPlanBuilder().plan(
            duration: .oneHour,
            snapshot: snapshot,
            weeklyHistory: .empty,
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(result.state, .unavailable)
        XCTAssertEqual(result.title, "작업 계획 대기")
        XCTAssertNil(result.currentUsedPercent)
        XCTAssertNil(result.projectedUsedPercent)
        XCTAssertEqual(result.sampleCount, 0)
    }

    func testThreeHourPlanUsesThreeHourDuration() throws {
        let now = 1_800_000_000
        let resetsAt = now + 4 * 60 * 60
        let previous = Self.weeklySample(
            recordedAt: now - 60 * 60,
            usedPercent: 35,
            resetsAt: resetsAt
        )
        let snapshot = Self.snapshot(
            cachedAt: now,
            staleAfterSeconds: 120,
            report: Self.report(weeklyUsedPercent: 40, weeklyResetsAt: resetsAt)
        )

        let result = CodexUsageSessionPlanBuilder().plan(
            duration: .threeHours,
            snapshot: snapshot,
            weeklyHistory: CodexUsageWeeklyHistory(samples: [previous]),
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(result.duration, .threeHours)
        XCTAssertEqual(result.durationSeconds, 10_800)
        XCTAssertEqual(result.state, .safe)
        XCTAssertEqual(try XCTUnwrap(result.projectedUsedPercent), 55, accuracy: 0.0001)
        XCTAssertEqual(result.title, "3시간 작업 여유")
    }

    func testWaitingForSamplesReturnsUnavailablePlanWithProjectionMetadata() {
        let now = 1_800_000_000
        let snapshot = Self.snapshot(
            cachedAt: now,
            staleAfterSeconds: 120,
            report: Self.report(weeklyUsedPercent: 46, weeklyResetsAt: now + 3 * 60 * 60)
        )

        let result = CodexUsageSessionPlanBuilder().plan(
            duration: .oneHour,
            snapshot: snapshot,
            weeklyHistory: .empty,
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(result.state, .unavailable)
        XCTAssertEqual(result.title, "작업 계획 대기")
        XCTAssertEqual(result.durationSeconds, 3_600)
        XCTAssertEqual(result.currentUsedPercent, 46)
        XCTAssertNil(result.projectedUsedPercent)
        XCTAssertEqual(result.sampleCount, 1)
    }

    private static func snapshot(
        cachedAt: Int,
        staleAfterSeconds: Int,
        report: CodexUsageReport?,
        error: CodexUsageCacheError? = nil
    ) -> CodexUsageCacheSnapshot {
        CodexUsageCacheSnapshot(
            cachedAt: cachedAt,
            staleAfterSeconds: staleAfterSeconds,
            report: report,
            error: error
        )
    }

    private static func weeklySample(
        recordedAt: Int,
        usedPercent: Double,
        resetsAt: Int
    ) -> CodexUsageWeeklyHistorySample {
        CodexUsageWeeklyHistorySample(
            recordedAt: recordedAt,
            usedPercent: usedPercent,
            remainingPercent: 100 - usedPercent,
            resetsAt: resetsAt,
            windowDurationMins: 10_080
        )
    }

    private static func report(
        weeklyUsedPercent: Double,
        weeklyResetsAt: Int
    ) -> CodexUsageReport {
        let fiveHour = UsageWindowReport(
            kind: .fiveHour,
            usedPercent: 12,
            remainingPercent: 88,
            windowDurationMins: 300,
            resetsAt: weeklyResetsAt - 7 * 24 * 60 * 60 + 5 * 60 * 60
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
