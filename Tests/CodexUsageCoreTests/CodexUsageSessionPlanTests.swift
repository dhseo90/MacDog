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
            snapshot: snapshot,
            weeklyHistory: CodexUsageWeeklyHistory(samples: [previous]),
            duration: .oneHour,
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(result.duration, .oneHour)
        XCTAssertEqual(result.durationSeconds, 3_600)
        XCTAssertEqual(result.state, .safe)
        XCTAssertEqual(result.availability, .ready)
        XCTAssertEqual(result.currentUsedPercent, 40)
        XCTAssertEqual(try XCTUnwrap(result.projectedUsedPercentAtEnd), 45, accuracy: 0.0001)
        XCTAssertEqual(result.sampleCount, 2)
        XCTAssertEqual(result.title, "1시간 작업 여유")
        XCTAssertEqual(result.detail, "예상 사용률 45%")
    }

    func testOneHourPlanWarnsWhenProjectedUsageIsExactlyEightyPercent() throws {
        let now = 1_800_000_000
        let resetsAt = now + 3 * 60 * 60
        let previous = Self.weeklySample(
            recordedAt: now - 60 * 60,
            usedPercent: 70,
            resetsAt: resetsAt
        )
        let snapshot = Self.snapshot(
            cachedAt: now,
            staleAfterSeconds: 120,
            report: Self.report(weeklyUsedPercent: 75, weeklyResetsAt: resetsAt)
        )

        let result = CodexUsageSessionPlanBuilder().plan(
            snapshot: snapshot,
            weeklyHistory: CodexUsageWeeklyHistory(samples: [previous]),
            duration: .oneHour,
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(result.state, .watch)
        XCTAssertEqual(result.availability, .ready)
        XCTAssertEqual(result.durationSeconds, 3_600)
        XCTAssertEqual(try XCTUnwrap(result.projectedUsedPercentAtEnd), 80, accuracy: 0.0001)
        XCTAssertEqual(result.title, "1시간 작업 주의")
        XCTAssertEqual(result.detail, "예상 사용률 80%")
    }

    func testOneHourPlanIsRiskyWhenProjectedUsageIsExactlyNinetyFivePercent() throws {
        let now = 1_800_000_000
        let resetsAt = now + 3 * 60 * 60
        let previous = Self.weeklySample(
            recordedAt: now - 60 * 60,
            usedPercent: 85,
            resetsAt: resetsAt
        )
        let snapshot = Self.snapshot(
            cachedAt: now,
            staleAfterSeconds: 120,
            report: Self.report(weeklyUsedPercent: 90, weeklyResetsAt: resetsAt)
        )

        let result = CodexUsageSessionPlanBuilder().plan(
            snapshot: snapshot,
            weeklyHistory: CodexUsageWeeklyHistory(samples: [previous]),
            duration: .oneHour,
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(result.state, .risky)
        XCTAssertEqual(result.availability, .ready)
        XCTAssertEqual(result.durationSeconds, 3_600)
        XCTAssertEqual(try XCTUnwrap(result.projectedUsedPercentAtEnd), 95, accuracy: 0.0001)
        XCTAssertEqual(result.title, "1시간 작업 위험")
        XCTAssertEqual(result.detail, "예상 사용률 95%")
    }

    func testProjectedUsageAtEndIsClampedAtOneHundredPercent() throws {
        let now = 1_800_000_000
        let resetsAt = now + 3 * 60 * 60
        let previous = Self.weeklySample(
            recordedAt: now - 60 * 60,
            usedPercent: 88,
            resetsAt: resetsAt
        )
        let snapshot = Self.snapshot(
            cachedAt: now,
            staleAfterSeconds: 120,
            report: Self.report(weeklyUsedPercent: 98, weeklyResetsAt: resetsAt)
        )

        let result = CodexUsageSessionPlanBuilder().plan(
            snapshot: snapshot,
            weeklyHistory: CodexUsageWeeklyHistory(samples: [previous]),
            duration: .oneHour,
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(result.state, .risky)
        XCTAssertEqual(result.availability, .ready)
        XCTAssertEqual(try XCTUnwrap(result.projectedUsedPercentAtEnd), 100, accuracy: 0.0001)
        XCTAssertEqual(result.detail, "예상 사용률 100%")
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
            snapshot: snapshot,
            weeklyHistory: CodexUsageWeeklyHistory(samples: [previous]),
            duration: .untilReset,
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(result.duration, .untilReset)
        XCTAssertEqual(result.durationSeconds, 7_200)
        XCTAssertEqual(result.state, .safe)
        XCTAssertEqual(result.availability, .ready)
        XCTAssertEqual(try XCTUnwrap(result.projectedUsedPercentAtEnd), 60, accuracy: 0.0001)
        XCTAssertEqual(result.detail, "예상 사용률 60%")
    }

    func testStaleUntilResetPlanKeepsDurationUnavailable() {
        let now = 1_800_000_000
        let snapshot = Self.snapshot(
            cachedAt: now - 300,
            staleAfterSeconds: 120,
            report: Self.report(weeklyUsedPercent: 50, weeklyResetsAt: now + 2 * 60 * 60)
        )

        let result = CodexUsageSessionPlanBuilder().plan(
            snapshot: snapshot,
            weeklyHistory: .empty,
            duration: .untilReset,
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(result.state, .unavailable)
        XCTAssertEqual(result.availability, .stale)
        XCTAssertNil(result.durationSeconds)
        XCTAssertEqual(result.title, "작업 계획 대기")
        XCTAssertNil(result.currentUsedPercent)
        XCTAssertNil(result.projectedUsedPercentAtEnd)
        XCTAssertEqual(result.sampleCount, 0)
        XCTAssertEqual(result.detail, "최신 cache가 확인되면 예상 사용률을 표시합니다.")
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
            snapshot: snapshot,
            weeklyHistory: CodexUsageWeeklyHistory(samples: [previous]),
            duration: .threeHours,
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(result.duration, .threeHours)
        XCTAssertEqual(result.durationSeconds, 10_800)
        XCTAssertEqual(result.state, .safe)
        XCTAssertEqual(result.availability, .ready)
        XCTAssertEqual(try XCTUnwrap(result.projectedUsedPercentAtEnd), 55, accuracy: 0.0001)
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
            snapshot: snapshot,
            weeklyHistory: .empty,
            duration: .oneHour,
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(result.state, .unavailable)
        XCTAssertEqual(result.availability, .waitingForSamples)
        XCTAssertEqual(result.title, "작업 계획 대기")
        XCTAssertNil(result.durationSeconds)
        XCTAssertEqual(result.currentUsedPercent, 46)
        XCTAssertNil(result.projectedUsedPercentAtEnd)
        XCTAssertEqual(result.sampleCount, 1)
        XCTAssertEqual(result.detail, "샘플이 더 쌓이면 예상 사용률을 표시합니다.")
    }

    func testNilSnapshotReturnsUnavailablePlanWithMissingSnapshotAvailability() {
        let result = CodexUsageSessionPlanBuilder().plan(
            snapshot: nil,
            weeklyHistory: .empty,
            duration: .oneHour,
            now: Date(timeIntervalSince1970: 1_800_000_000)
        )

        XCTAssertEqual(result.state, .unavailable)
        XCTAssertEqual(result.availability, .missingSnapshot)
        XCTAssertNil(result.durationSeconds)
        XCTAssertNil(result.currentUsedPercent)
        XCTAssertNil(result.projectedUsedPercentAtEnd)
        XCTAssertEqual(result.sampleCount, 0)
        XCTAssertEqual(result.title, "작업 계획 대기")
        XCTAssertEqual(result.detail, "사용량 데이터가 준비되면 예상 사용률을 표시합니다.")
    }

    func testErrorSnapshotKeepsErrorAvailabilityWithoutExposingMessage() {
        let now = 1_800_000_000
        let message = "token refresh failed"
        let snapshot = Self.snapshot(
            cachedAt: now,
            staleAfterSeconds: 120,
            report: Self.report(weeklyUsedPercent: 46, weeklyResetsAt: now + 3 * 60 * 60),
            error: CodexUsageCacheError(message: message, recordedAt: now)
        )

        let result = CodexUsageSessionPlanBuilder().plan(
            snapshot: snapshot,
            weeklyHistory: .empty,
            duration: .oneHour,
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(result.state, .unavailable)
        XCTAssertEqual(result.availability, .error)
        XCTAssertNil(result.durationSeconds)
        XCTAssertNil(result.currentUsedPercent)
        XCTAssertNil(result.projectedUsedPercentAtEnd)
        XCTAssertEqual(result.sampleCount, 0)
        XCTAssertEqual(result.detail, "오류 상태라 작업 계획을 계산하지 않습니다.")
        XCTAssertFalse(result.detail.contains(message))
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
