import XCTest
@testable import CodexUsageCore

final class RateLimitModelsTests: XCTestCase {
    func testDecodesCodexRateLimitBucket() throws {
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: "rate_limits_response",
            withExtension: "json"
        ))
        let data = try Data(contentsOf: url)
        let response = try JSONDecoder().decode(RateLimitsResponse.self, from: data)
        let bucket = response.codexBucket

        XCTAssertEqual(bucket.limitId, "codex")
        XCTAssertEqual(bucket.planType, "pro")
        XCTAssertEqual(bucket.credits?.balance, "0")
        XCTAssertEqual(bucket.fiveHourWindow?.usedPercent, 15)
        XCTAssertEqual(bucket.fiveHourWindow?.remainingPercent, 85)
        XCTAssertEqual(bucket.weeklyWindow?.usedPercent, 38)
        XCTAssertEqual(bucket.weeklyWindow?.remainingPercent, 62)
    }

    func testIdentifiesKnownWindowDurations() {
        XCTAssertEqual(
            RateLimitWindow(usedPercent: 1, windowDurationMins: 300, resetsAt: nil).identifiedKind,
            .fiveHour
        )
        XCTAssertEqual(
            RateLimitWindow(usedPercent: 1, windowDurationMins: 10_080, resetsAt: nil).identifiedKind,
            .weekly
        )
        XCTAssertEqual(
            RateLimitWindow(usedPercent: 1, windowDurationMins: 60, resetsAt: nil).identifiedKind,
            .other
        )
    }
}
