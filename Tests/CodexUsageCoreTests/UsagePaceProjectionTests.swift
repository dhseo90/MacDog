import XCTest
@testable import CodexUsageCore

final class UsagePaceProjectionTests: XCTestCase {
    func testProjectsFinalUsageFromRecentSampleDeltaWithinSameResetWindow() throws {
        let now = 1_800_000_000
        let resetsAt = now + 3 * 60 * 60
        let previous = Self.weeklySample(
            recordedAt: now - 60 * 60,
            usedPercent: 40,
            resetsAt: resetsAt
        )
        let snapshot = Self.snapshot(
            cachedAt: now,
            staleAfterSeconds: 120,
            report: Self.report(weeklyUsedPercent: 46, weeklyResetsAt: resetsAt)
        )

        let result = CodexUsagePaceProjectionBuilder().projection(
            snapshot: snapshot,
            weeklyHistory: CodexUsageWeeklyHistory(samples: [previous]),
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(result.state, .projected)
        XCTAssertEqual(result.sampleCount, 2)
        XCTAssertEqual(result.currentUsedPercent, 46)
        XCTAssertEqual(try XCTUnwrap(result.usedPercentPerHour), 6, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(result.projectedFinalUsedPercent), 64, accuracy: 0.0001)
        XCTAssertEqual(result.remainingSeconds, 3 * 60 * 60)
    }

    func testWaitsForSamplesWhenOnlyCurrentSampleIsAvailable() throws {
        let now = 1_800_000_000
        let resetsAt = now + 3 * 60 * 60
        let snapshot = Self.snapshot(
            cachedAt: now,
            staleAfterSeconds: 120,
            report: Self.report(weeklyUsedPercent: 46, weeklyResetsAt: resetsAt)
        )

        let result = CodexUsagePaceProjectionBuilder().projection(
            snapshot: snapshot,
            weeklyHistory: .empty,
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(result.state, .waitingForSamples)
        XCTAssertEqual(result.sampleCount, 1)
        XCTAssertEqual(result.currentUsedPercent, 46)
        XCTAssertNil(result.projectedFinalUsedPercent)
        XCTAssertNil(result.usedPercentPerHour)
    }

    func testSeparatesStaleCacheFromSampleShortage() throws {
        let now = 1_800_000_000
        let snapshot = Self.snapshot(
            cachedAt: now - 300,
            staleAfterSeconds: 120,
            report: Self.report(weeklyUsedPercent: 46, weeklyResetsAt: now + 3 * 60 * 60)
        )

        let result = CodexUsagePaceProjectionBuilder().projection(
            snapshot: snapshot,
            weeklyHistory: .empty,
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(result.state, .stale)
        XCTAssertEqual(result.sampleCount, 0)
        XCTAssertNil(result.projectedFinalUsedPercent)
    }

    func testSeparatesErrorCacheFromStaleCache() throws {
        let now = 1_800_000_000
        let snapshot = Self.snapshot(
            cachedAt: now,
            staleAfterSeconds: 120,
            report: Self.report(weeklyUsedPercent: 46, weeklyResetsAt: now + 3 * 60 * 60),
            error: CodexUsageCacheError(message: "network unavailable", recordedAt: now)
        )

        let result = CodexUsagePaceProjectionBuilder().projection(
            snapshot: snapshot,
            weeklyHistory: .empty,
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(result.state, .error(message: "network unavailable"))
        XCTAssertEqual(result.sampleCount, 0)
        XCTAssertNil(result.projectedFinalUsedPercent)
    }

    func testIgnoresSamplesFromDifferentResetWindows() throws {
        let now = 1_800_000_000
        let resetsAt = now + 3 * 60 * 60
        let previousWindowSample = Self.weeklySample(
            recordedAt: now - 60 * 60,
            usedPercent: 40,
            resetsAt: resetsAt - 10_080 * 60
        )
        let snapshot = Self.snapshot(
            cachedAt: now,
            staleAfterSeconds: 120,
            report: Self.report(weeklyUsedPercent: 46, weeklyResetsAt: resetsAt)
        )

        let result = CodexUsagePaceProjectionBuilder().projection(
            snapshot: snapshot,
            weeklyHistory: CodexUsageWeeklyHistory(samples: [previousWindowSample]),
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(result.state, .waitingForSamples)
        XCTAssertEqual(result.sampleCount, 1)
        XCTAssertNil(result.projectedFinalUsedPercent)
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
