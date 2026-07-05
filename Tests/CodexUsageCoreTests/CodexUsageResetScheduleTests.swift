import XCTest
@testable import CodexUsageCore

final class CodexUsageResetScheduleTests: XCTestCase {
    func testBuildsFreshPrimaryEntriesSortedByResetTime() throws {
        let now = 1_800_000_000
        let report = Self.report(
            fiveHourUsedPercent: 42,
            fiveHourResetsAt: now + 3_600,
            weeklyUsedPercent: 64,
            weeklyResetsAt: now + 604_800
        )
        let snapshot = Self.snapshot(cachedAt: now, staleAfterSeconds: 120, report: report)

        let schedule = CodexUsageResetScheduleBuilder().schedule(
            snapshot: snapshot,
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(schedule.state, .ok)
        XCTAssertEqual(schedule.primaryEntries.map(\.title), ["5시간", "주간"])
        XCTAssertEqual(schedule.primaryEntries.map(\.kind), [.fiveHour, .weekly])
        XCTAssertEqual(schedule.primaryEntries.map(\.remainingSeconds), [3_600, 604_800])
        XCTAssertEqual(schedule.primaryEntries.map(\.remainingPercent), [58, 36])
        XCTAssertEqual(schedule.primaryEntries.map(\.trustState), [.fresh, .fresh])
        XCTAssertEqual(schedule.primaryEntries.map(\.isNextRecovery), [true, false])
        XCTAssertEqual(schedule.summaryText, "회복 카드 2장 · 다음 5시간 1시간 후")
    }

    func testClassifiesPrimaryAndSecondaryDurationsFromReportBuilder() throws {
        let now = 1_800_000_000
        let response = RateLimitsResponse(
            rateLimits: Self.rateLimitSnapshot(
                id: "codex",
                primary: RateLimitWindow(usedPercent: 12, windowDurationMins: 300, resetsAt: now + 3_600),
                secondary: RateLimitWindow(usedPercent: 34, windowDurationMins: 10_080, resetsAt: now + 604_800)
            ),
            rateLimitsByLimitId: nil
        )
        let report = try CodexUsageReportBuilder(dateProvider: {
            Date(timeIntervalSince1970: TimeInterval(now))
        }).build(from: response)

        let schedule = CodexUsageResetScheduleBuilder().schedule(
            report: report,
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(schedule.primaryEntries.map(\.title), ["5시간", "주간"])
        XCTAssertEqual(schedule.primaryEntries.map(\.kind), [.fiveHour, .weekly])
        XCTAssertEqual(schedule.primaryEntries.map(\.windowDurationMins), [300, 10_080])
    }

    func testMarksEntriesStaleWhenCacheIsStale() throws {
        let now = 1_800_000_000
        let snapshot = Self.snapshot(
            cachedAt: now - 300,
            staleAfterSeconds: 120,
            report: Self.report(
                fiveHourUsedPercent: 42,
                fiveHourResetsAt: now + 3_600,
                weeklyUsedPercent: 64,
                weeklyResetsAt: now + 604_800
            )
        )

        let schedule = CodexUsageResetScheduleBuilder().schedule(
            snapshot: snapshot,
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(schedule.state, .stale)
        XCTAssertEqual(Set(schedule.entries.map(\.trustState)), [.stale])
        XCTAssertEqual(schedule.trustSummary, "마지막 확인 기준")
    }

    func testReportsErrorStateButUsesLastSuccessReportWhenPresent() throws {
        let now = 1_800_000_000
        let snapshot = Self.snapshot(
            cachedAt: now,
            staleAfterSeconds: 120,
            report: Self.report(
                fiveHourUsedPercent: 42,
                fiveHourResetsAt: now + 3_600,
                weeklyUsedPercent: 64,
                weeklyResetsAt: now + 604_800
            ),
            error: CodexUsageCacheError(message: "network unavailable", recordedAt: now)
        )

        let schedule = CodexUsageResetScheduleBuilder().schedule(
            snapshot: snapshot,
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(schedule.state, .error)
        XCTAssertEqual(Set(schedule.entries.map(\.trustState)), [.error])
        XCTAssertEqual(schedule.trustSummary, "오류 상태 함께 표시")
        XCTAssertFalse(schedule.primaryEntries.isEmpty)
    }

    func testReportsErrorStateWhenErrorSnapshotHasNoReport() throws {
        let now = 1_800_000_000
        let snapshot = Self.snapshot(
            cachedAt: now,
            staleAfterSeconds: 120,
            report: nil,
            error: CodexUsageCacheError(message: "network unavailable", recordedAt: now)
        )

        let schedule = CodexUsageResetScheduleBuilder().schedule(
            snapshot: snapshot,
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(schedule.state, .error)
        XCTAssertTrue(schedule.entries.isEmpty)
        XCTAssertEqual(schedule.trustSummary, "오류 상태 함께 표시")
    }

    func testReturnsWaitingScheduleWhenReportIsMissing() throws {
        let now = 1_800_000_000
        let snapshot = Self.snapshot(cachedAt: now, staleAfterSeconds: 120, report: nil)

        let schedule = CodexUsageResetScheduleBuilder().schedule(
            snapshot: snapshot,
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(schedule.state, .waiting)
        XCTAssertTrue(schedule.entries.isEmpty)
        XCTAssertEqual(schedule.summaryText, "회복 일정 대기")
    }

    func testDoesNotMarkNextRecoveryWhenResetTimesAreMissing() throws {
        let now = 1_800_000_000
        let report = Self.report(
            fiveHourUsedPercent: 42,
            fiveHourResetsAt: nil,
            weeklyUsedPercent: 64,
            weeklyResetsAt: nil
        )

        let schedule = CodexUsageResetScheduleBuilder().schedule(
            report: report,
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(schedule.primaryEntries.count, 2)
        XCTAssertNil(schedule.nextRecovery)
        XCTAssertEqual(schedule.primaryEntries.map(\.isNextRecovery), [false, false])
        XCTAssertEqual(schedule.summaryText, "회복 카드 2장")
    }

    func testUsesStableTieBreakerWhenResetTimesMatch() throws {
        let now = 1_800_000_000
        let report = Self.report(
            fiveHourUsedPercent: 42,
            fiveHourResetsAt: now + 3_600,
            weeklyUsedPercent: 64,
            weeklyResetsAt: now + 3_600
        )

        let schedule = CodexUsageResetScheduleBuilder().schedule(
            report: report,
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(schedule.primaryEntries.map(\.kind), [.fiveHour, .weekly])
        XCTAssertEqual(schedule.primaryEntries.map(\.isNextRecovery), [true, false])
    }

    func testReportsProtocolDriftWhenRequiredCodexWindowsAreMissing() throws {
        let now = 1_800_000_000
        let incomplete = UsageLimitReport(
            limitId: "codex",
            limitName: "Codex",
            primary: UsageWindowReport(
                kind: .fiveHour,
                usedPercent: 12,
                remainingPercent: 88,
                windowDurationMins: 300,
                resetsAt: now + 3_600
            ),
            secondary: nil,
            credits: nil,
            planType: "pro",
            rateLimitReachedType: nil
        )
        let report = CodexUsageReport(
            generatedAt: now,
            source: "test",
            planType: "pro",
            credits: nil,
            rateLimitReachedType: nil,
            limits: ["codex": incomplete]
        )

        let schedule = CodexUsageResetScheduleBuilder().schedule(
            report: report,
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(schedule.state, .protocolDrift)
        XCTAssertTrue(schedule.primaryEntries.isEmpty)
        XCTAssertTrue(schedule.advancedEntries.isEmpty)
        XCTAssertEqual(schedule.summaryText, "필수 5시간/주간 window 확인 필요")
    }

    func testKeepsAdditionalBucketsInAdvancedEntries() throws {
        let now = 1_800_000_000
        let codex = Self.limit(
            id: "codex",
            fiveHourUsedPercent: 20,
            fiveHourResetsAt: now + 3_600,
            weeklyUsedPercent: 35,
            weeklyResetsAt: now + 604_800
        )
        let extra = Self.limit(
            id: "codex_bengalfox",
            fiveHourUsedPercent: 70,
            fiveHourResetsAt: now + 1_800,
            weeklyUsedPercent: 80,
            weeklyResetsAt: now + 86_400
        )
        let report = CodexUsageReport(
            generatedAt: now,
            source: "test",
            planType: "pro",
            credits: nil,
            rateLimitReachedType: nil,
            limits: ["codex": codex, "codex_bengalfox": extra]
        )

        let schedule = CodexUsageResetScheduleBuilder().schedule(
            report: report,
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(schedule.primaryEntries.map(\.limitId), ["codex", "codex"])
        XCTAssertEqual(schedule.primaryEntries.map(\.isNextRecovery), [true, false])
        XCTAssertEqual(schedule.advancedEntries.map(\.limitId), ["codex_bengalfox", "codex_bengalfox"])
        XCTAssertEqual(schedule.advancedEntries.map(\.scope), [.advanced, .advanced])
        XCTAssertEqual(schedule.advancedEntries.map(\.isNextRecovery), [false, false])
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

    private static func report(
        fiveHourUsedPercent: Double,
        fiveHourResetsAt: Int?,
        weeklyUsedPercent: Double,
        weeklyResetsAt: Int?
    ) -> CodexUsageReport {
        CodexUsageReport(
            generatedAt: 0,
            source: "test",
            planType: "pro",
            credits: nil,
            rateLimitReachedType: nil,
            limits: [
                "codex": limit(
                    id: "codex",
                    fiveHourUsedPercent: fiveHourUsedPercent,
                    fiveHourResetsAt: fiveHourResetsAt,
                    weeklyUsedPercent: weeklyUsedPercent,
                    weeklyResetsAt: weeklyResetsAt
                )
            ]
        )
    }

    private static func limit(
        id: String,
        fiveHourUsedPercent: Double,
        fiveHourResetsAt: Int?,
        weeklyUsedPercent: Double,
        weeklyResetsAt: Int?
    ) -> UsageLimitReport {
        UsageLimitReport(
            limitId: id,
            limitName: id,
            primary: UsageWindowReport(
                kind: .fiveHour,
                usedPercent: fiveHourUsedPercent,
                remainingPercent: 100 - fiveHourUsedPercent,
                windowDurationMins: 300,
                resetsAt: fiveHourResetsAt
            ),
            secondary: UsageWindowReport(
                kind: .weekly,
                usedPercent: weeklyUsedPercent,
                remainingPercent: 100 - weeklyUsedPercent,
                windowDurationMins: 10_080,
                resetsAt: weeklyResetsAt
            ),
            credits: nil,
            planType: "pro",
            rateLimitReachedType: nil
        )
    }

    private static func rateLimitSnapshot(
        id: String,
        primary: RateLimitWindow?,
        secondary: RateLimitWindow?
    ) -> RateLimitSnapshot {
        RateLimitSnapshot(
            limitId: id,
            limitName: id,
            primary: primary,
            secondary: secondary,
            credits: nil,
            planType: "pro",
            rateLimitReachedType: nil
        )
    }
}
