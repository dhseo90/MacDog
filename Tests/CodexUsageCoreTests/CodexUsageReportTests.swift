import XCTest
@testable import CodexUsageCore

final class CodexUsageReportTests: XCTestCase {
    func testBuildsStableReportFromRateLimitsResponse() throws {
        let response = try loadFixture()
        let builder = CodexUsageReportBuilder(dateProvider: {
            Date(timeIntervalSince1970: 1_779_700_000)
        })

        let report = try builder.build(from: response)

        XCTAssertEqual(report.generatedAt, 1_779_700_000)
        XCTAssertEqual(report.source, "codex-app-server")
        XCTAssertEqual(report.planType, "pro")
        XCTAssertEqual(report.codexLimit?.fiveHour?.usedPercent, 15)
        XCTAssertEqual(report.codexLimit?.weekly?.usedPercent, 38)
        XCTAssertEqual(report.codexLimit?.maxUsedPercent, 38)
        XCTAssertNotNil(report.limits["codex_bengalfox"])
    }

    func testBuildsDiagnosticReportWithoutChangingUsageReport() throws {
        let fixtureData = try loadFixtureData()
        let response = try JSONDecoder().decode(RateLimitsResponse.self, from: fixtureData)
        let fixtureObject = try XCTUnwrap(JSONSerialization.jsonObject(with: fixtureData) as? [String: Any])
        let fieldInventory = CodexUsageFieldInventory.make(fromRateLimitsObject: fixtureObject)
        let builder = CodexUsageReportBuilder(dateProvider: {
            Date(timeIntervalSince1970: 1_779_700_000)
        })

        let diagnostic = try builder.buildDiagnosticReport(
            from: response,
            fieldInventory: fieldInventory
        )

        XCTAssertEqual(diagnostic.report.generatedAt, 1_779_700_000)
        XCTAssertEqual(diagnostic.report.codexLimit?.fiveHour?.remainingPercent, 85)
        XCTAssertEqual(diagnostic.fieldInventory.buckets.map(\.key), ["codex", "codex_bengalfox"])
    }

    func testFormatsTextReport() throws {
        let response = try loadFixture()
        let report = try CodexUsageReportBuilder(dateProvider: {
            Date(timeIntervalSince1970: 1_779_700_000)
        }).build(from: response)
        let formatter = CodexUsageFormatter(
            timeZone: TimeZone(secondsFromGMT: 9 * 60 * 60)!,
            locale: Locale(identifier: "en_US_POSIX")
        )

        let text = formatter.text(from: report)

        XCTAssertTrue(text.contains("Codex usage"))
        XCTAssertTrue(text.contains("5h: 15% used, 85% remaining"))
        XCTAssertTrue(text.contains("Weekly: 38% used, 62% remaining"))
        XCTAssertTrue(text.contains("Credits: 0"))
        XCTAssertTrue(text.contains("Plan: pro"))
    }

    func testFormatsJSONReport() throws {
        let response = try loadFixture()
        let report = try CodexUsageReportBuilder(dateProvider: {
            Date(timeIntervalSince1970: 1_779_700_000)
        }).build(from: response)
        let data = try CodexUsageFormatter().json(from: report)
        let json = String(decoding: data, as: UTF8.self)

        XCTAssertTrue(json.contains("\"generatedAt\" : 1779700000"))
        XCTAssertTrue(json.contains("\"codex\""))
        XCTAssertTrue(json.contains("\"remainingPercent\" : 85"))
    }

    func testFormatsCacheWriteHistoryDiagnosticLine() {
        let result = CodexUsageCacheWriteResult(
            cachedAt: 1_800_000_000,
            cacheFileURL: URL(fileURLWithPath: "/tmp/MacDog/usage.json"),
            weeklyHistory: CodexUsageWeeklyHistoryWriteResult(
                disposition: .stored,
                fileURL: URL(fileURLWithPath: "/tmp/MacDog/usage-weekly-history.json"),
                recordedAt: 1_800_000_000,
                recordingStartedAt: 1_800_000_000,
                remainingPercent: 62,
                resetsAt: 1_800_345_600
            )
        )

        let line = CodexUsageCacheWriteDiagnosticFormatter().line(from: result)

        XCTAssertEqual(
            line,
            "history append: stored recordedAt=2027-01-15T08:00:00Z recordingStartedAt=2027-01-15T08:00:00Z remaining=62% resetsAt=2027-01-19T08:00:00Z path=/tmp/MacDog/usage-weekly-history.json"
        )
    }

    func testRejectsCodexBucketWithoutFiveHourAndWeeklyWindows() throws {
        let incompleteCodexBucket = RateLimitSnapshot(
            limitId: "codex",
            limitName: nil,
            primary: RateLimitWindow(usedPercent: 0, windowDurationMins: nil, resetsAt: nil),
            secondary: nil,
            credits: CreditsSnapshot(hasCredits: false, unlimited: false, balance: "0"),
            planType: "pro",
            rateLimitReachedType: nil
        )
        let response = RateLimitsResponse(
            rateLimits: incompleteCodexBucket,
            rateLimitsByLimitId: ["codex": incompleteCodexBucket]
        )

        XCTAssertThrowsError(try CodexUsageReportBuilder().build(from: response)) { error in
            XCTAssertTrue(error.localizedDescription.contains("missing required codex usage windows"))
            XCTAssertTrue(error.localizedDescription.contains("5-hour"))
            XCTAssertTrue(error.localizedDescription.contains("weekly"))
        }
    }

    private func loadFixture() throws -> RateLimitsResponse {
        try JSONDecoder().decode(RateLimitsResponse.self, from: loadFixtureData())
    }

    private func loadFixtureData() throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: "rate_limits_response",
            withExtension: "json"
        ))
        return try Data(contentsOf: url)
    }
}
