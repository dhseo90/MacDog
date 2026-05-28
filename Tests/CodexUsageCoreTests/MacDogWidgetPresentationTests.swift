import XCTest
@testable import CodexUsageCore
@testable import MacDogWidget

final class MacDogWidgetPresentationTests: XCTestCase {
    func testPresentationShowsNoCacheWhenSnapshotIsMissing() {
        let entry = CodexUsageEntry(date: Date(timeIntervalSince1970: 1_779_800_000), snapshot: nil, errorMessage: nil)
        let presentation = WidgetUsagePresentation(entry: entry)

        XCTAssertEqual(presentation.statusText, "캐시 없음")
        XCTAssertEqual(presentation.maxUsedPercent, 0)
    }

    func testPresentationShowsUpdatedCacheAndMaxUsage() {
        let entry = CodexUsageEntry(
            date: Date(timeIntervalSince1970: 1_779_800_030),
            snapshot: makeSnapshot(cachedAt: 1_779_800_000, staleAfterSeconds: 60),
            errorMessage: nil
        )
        let presentation = WidgetUsagePresentation(entry: entry)

        XCTAssertEqual(presentation.statusText, "갱신됨")
        XCTAssertEqual(presentation.maxUsedPercent, 38)
    }

    func testPresentationShowsStaleCacheWhenSnapshotIsOld() {
        let entry = CodexUsageEntry(
            date: Date(timeIntervalSince1970: 1_779_800_061),
            snapshot: makeSnapshot(cachedAt: 1_779_800_000, staleAfterSeconds: 60),
            errorMessage: nil
        )
        let presentation = WidgetUsagePresentation(entry: entry)

        XCTAssertEqual(presentation.statusText, "오래된 캐시")
    }

    func testPresentationShowsErrorStateFromCacheSnapshot() {
        let snapshot = makeSnapshot(
            cachedAt: 1_779_800_000,
            staleAfterSeconds: 60,
            error: CodexUsageCacheError(message: "network unavailable", recordedAt: 1_779_800_010)
        )
        let entry = CodexUsageEntry(
            date: Date(timeIntervalSince1970: 1_779_800_011),
            snapshot: snapshot,
            errorMessage: snapshot.error?.message
        )
        let presentation = WidgetUsagePresentation(entry: entry)

        XCTAssertEqual(presentation.statusText, "오류: network unavailable")
        XCTAssertEqual(presentation.maxUsedPercent, 38)
    }

    private func makeSnapshot(
        cachedAt: Int,
        staleAfterSeconds: Int,
        error: CodexUsageCacheError? = nil
    ) -> CodexUsageCacheSnapshot {
        CodexUsageCacheSnapshot(
            cachedAt: cachedAt,
            staleAfterSeconds: staleAfterSeconds,
            report: makeReport(),
            error: error
        )
    }

    private func makeReport() -> CodexUsageReport {
        let fiveHour = UsageWindowReport(
            kind: .fiveHour,
            usedPercent: 15,
            remainingPercent: 85,
            windowDurationMins: 300,
            resetsAt: 1_779_801_000
        )
        let weekly = UsageWindowReport(
            kind: .weekly,
            usedPercent: 38,
            remainingPercent: 62,
            windowDurationMins: 10_080,
            resetsAt: 1_780_000_000
        )
        let credits = CreditsSnapshot(hasCredits: false, unlimited: false, balance: "0")
        let limit = UsageLimitReport(
            limitId: "codex",
            limitName: nil,
            primary: fiveHour,
            secondary: weekly,
            credits: credits,
            planType: "pro",
            rateLimitReachedType: nil
        )
        return CodexUsageReport(
            generatedAt: 1_779_800_000,
            source: "fixture",
            planType: "pro",
            credits: credits,
            rateLimitReachedType: nil,
            limits: ["codex": limit]
        )
    }
}
