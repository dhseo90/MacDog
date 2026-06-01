import XCTest
@testable import CodexUsageCore
@testable import MacDogWidget

final class MacDogWidgetPresentationTests: XCTestCase {
    func testWidgetDeepLinkTargetsMacDogOpenURL() {
        XCTAssertEqual(MacDogWidgetDeepLink.openURL.absoluteString, "macdog://open")
    }

    func testPresentationShowsNoCacheWhenSnapshotIsMissing() {
        let entry = CodexUsageEntry(date: Date(timeIntervalSince1970: 1_779_800_000), snapshot: nil, errorMessage: nil)
        let presentation = WidgetUsagePresentation(entry: entry)

        XCTAssertEqual(presentation.statusText, "캐시 없음")
        XCTAssertEqual(presentation.maxUsedPercent, 0)
        XCTAssertEqual(presentation.resetText, "초기화 시각 알 수 없음")
        XCTAssertEqual(presentation.metadataText, "크레딧 알 수 없음 · 갱신 알 수 없음")
    }

    func testTimelineProviderTreatsMissingCacheAsNoCache() {
        let error = NSError(
            domain: NSCocoaErrorDomain,
            code: CocoaError.fileReadNoSuchFile.rawValue,
            userInfo: [NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: Int(POSIXErrorCode.ENOENT.rawValue))]
        )

        XCTAssertTrue(CodexUsageTimelineProvider.isMissingCacheError(error))
    }

    func testPresentationShowsGenericReadFailureWithoutRawFilePath() {
        let entry = CodexUsageEntry(
            date: Date(timeIntervalSince1970: 1_779_800_000),
            snapshot: nil,
            errorMessage: "캐시를 읽을 수 없음"
        )
        let presentation = WidgetUsagePresentation(entry: entry)

        XCTAssertEqual(presentation.statusText, "오류: 캐시를 읽을 수 없음")
        XCTAssertFalse(presentation.statusText.contains("usage.json"))
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
        XCTAssertEqual(presentation.resetText, "주간 초기화까지 2일 7시간 남음")
        XCTAssertEqual(presentation.metadataText, "크레딧 0 · 갱신 방금")
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
        XCTAssertEqual(presentation.resetText, "주간 초기화까지 2일 7시간 남음")
        XCTAssertEqual(presentation.metadataText, "크레딧 0 · 갱신 방금")
    }

    func testPresentationShowsResetCountdownForHighestUsageWindow() {
        let entry = CodexUsageEntry(
            date: Date(timeIntervalSince1970: 1_800_000_000),
            snapshot: makeSnapshot(
                cachedAt: 1_800_000_000,
                staleAfterSeconds: 60,
                report: makeReport(
                    fiveHourUsedPercent: 82,
                    weeklyUsedPercent: 68,
                    fiveHourResetsAt: 1_800_007_200,
                    weeklyResetsAt: 1_800_345_600
                )
            ),
            errorMessage: nil
        )
        let presentation = WidgetUsagePresentation(entry: entry)

        XCTAssertEqual(presentation.maxUsedPercent, 82)
        XCTAssertEqual(presentation.resetText, "5시간 초기화까지 2시간 남음")
        XCTAssertEqual(presentation.metadataText, "크레딧 0 · 갱신 방금")
    }

    func testWidgetResetTextHandlesMissingAndPastResetTime() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let window = UsageWindowReport(
            kind: .fiveHour,
            usedPercent: 15,
            remainingPercent: 85,
            windowDurationMins: 300,
            resetsAt: 1_799_999_940
        )

        XCTAssertEqual(
            WidgetUsagePresentation.resetText(label: "5시간", window: nil, now: now),
            "5시간 확인 불가"
        )
        XCTAssertEqual(
            WidgetUsagePresentation.resetText(
                label: "5시간",
                window: UsageWindowReport(
                    kind: .fiveHour,
                    usedPercent: 15,
                    remainingPercent: 85,
                    windowDurationMins: 300,
                    resetsAt: nil
                ),
                now: now
            ),
            "5시간 초기화 시각 알 수 없음"
        )
        XCTAssertEqual(
            WidgetUsagePresentation.resetText(label: "5시간", window: window, now: now),
            "5시간 초기화 확인 중"
        )
    }

    func testWidgetMetadataShowsCreditsAndRelativeUpdateAge() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let unlimitedReport = makeReport(credits: CreditsSnapshot(hasCredits: true, unlimited: true, balance: nil))

        XCTAssertEqual(
            WidgetUsagePresentation.metadataText(
                report: makeReport(credits: CreditsSnapshot(hasCredits: true, unlimited: false, balance: "12")),
                cachedAt: 1_799_999_820,
                now: now
            ),
            "크레딧 12 · 갱신 3분 전"
        )
        XCTAssertEqual(
            WidgetUsagePresentation.metadataText(
                report: unlimitedReport,
                cachedAt: 1_799_989_200,
                now: now
            ),
            "크레딧 무제한 · 갱신 3시간 전"
        )
        XCTAssertEqual(
            WidgetUsagePresentation.metadataText(
                report: nil,
                cachedAt: 1_799_740_800,
                now: now
            ),
            "크레딧 알 수 없음 · 갱신 3일 전"
        )
    }

    private func makeSnapshot(
        cachedAt: Int,
        staleAfterSeconds: Int,
        report: CodexUsageReport? = nil,
        error: CodexUsageCacheError? = nil
    ) -> CodexUsageCacheSnapshot {
        CodexUsageCacheSnapshot(
            cachedAt: cachedAt,
            staleAfterSeconds: staleAfterSeconds,
            report: report ?? makeReport(),
            error: error
        )
    }

    private func makeReport(
        fiveHourUsedPercent: Double = 15,
        weeklyUsedPercent: Double = 38,
        fiveHourResetsAt: Int? = 1_779_801_000,
        weeklyResetsAt: Int? = 1_780_000_000,
        credits: CreditsSnapshot = CreditsSnapshot(hasCredits: false, unlimited: false, balance: "0")
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
