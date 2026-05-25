import XCTest
@testable import CodexUsageCore

final class CodexUsageReportTests: XCTestCase {
    func testBuildsStableReportFromRateLimitsResponse() throws {
        let response = try loadFixture()
        let builder = CodexUsageReportBuilder(dateProvider: {
            Date(timeIntervalSince1970: 1_779_700_000)
        })

        let report = builder.build(from: response)

        XCTAssertEqual(report.generatedAt, 1_779_700_000)
        XCTAssertEqual(report.source, "codex-app-server")
        XCTAssertEqual(report.planType, "pro")
        XCTAssertEqual(report.codexLimit?.fiveHour?.usedPercent, 15)
        XCTAssertEqual(report.codexLimit?.weekly?.usedPercent, 38)
        XCTAssertEqual(report.codexLimit?.maxUsedPercent, 38)
        XCTAssertNotNil(report.limits["codex_bengalfox"])
    }

    func testFormatsTextReport() throws {
        let response = try loadFixture()
        let report = CodexUsageReportBuilder(dateProvider: {
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
        let report = CodexUsageReportBuilder(dateProvider: {
            Date(timeIntervalSince1970: 1_779_700_000)
        }).build(from: response)
        let data = try CodexUsageFormatter().json(from: report)
        let json = String(decoding: data, as: UTF8.self)

        XCTAssertTrue(json.contains("\"generatedAt\" : 1779700000"))
        XCTAssertTrue(json.contains("\"codex\""))
        XCTAssertTrue(json.contains("\"remainingPercent\" : 85"))
    }

    private func loadFixture() throws -> RateLimitsResponse {
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: "rate_limits_response",
            withExtension: "json"
        ))
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(RateLimitsResponse.self, from: data)
    }
}

