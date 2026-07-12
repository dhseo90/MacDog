import XCTest
@testable import CodexUsageCore

final class ClaudeStatusLineSnapshotTests: XCTestCase {
    private let sanitizer = ClaudeStatusLineSanitizer()

    func testDecodesOfficialFiveHourAndSevenDayShape() throws {
        let snapshot = try sanitizer.snapshot(
            from: fixture(named: "claude_status_line_full"),
            observedAt: 1_900_000_000
        )

        XCTAssertEqual(snapshot.provider, "claude")
        XCTAssertEqual(snapshot.observedAt, 1_900_000_000)
        XCTAssertEqual(snapshot.model?.id, "claude-opus-4-1")
        XCTAssertEqual(snapshot.model?.displayName, "Opus")
        XCTAssertEqual(snapshot.fiveHour?.usedPercent, 42.5)
        XCTAssertEqual(snapshot.fiveHour?.resetsAt, 1_900_010_000)
        XCTAssertEqual(snapshot.sevenDay?.usedPercent, 61)
        XCTAssertEqual(snapshot.sevenDay?.resetsAt, 1_900_600_000)
    }

    func testEachWindowCanBeIndependentlyAbsent() throws {
        let fiveHourOnly = try sanitizer.snapshot(
            from: fixture(named: "claude_status_line_five_hour_only"),
            observedAt: 1
        )
        let sevenDayOnly = try sanitizer.snapshot(
            from: fixture(named: "claude_status_line_seven_day_only"),
            observedAt: 2
        )

        XCTAssertNotNil(fiveHourOnly.fiveHour)
        XCTAssertNil(fiveHourOnly.sevenDay)
        XCTAssertNil(sevenDayOnly.fiveHour)
        XCTAssertNotNil(sevenDayOnly.sevenDay)
    }

    func testMissingRateLimitsProducesWaitingSnapshot() throws {
        let snapshot = try sanitizer.snapshot(
            from: fixture(named: "claude_status_line_missing_rate_limits"),
            observedAt: 3
        )

        XCTAssertFalse(snapshot.hasUsageData)
        XCTAssertNil(snapshot.fiveHour)
        XCTAssertNil(snapshot.sevenDay)
    }

    func testNullAndUnknownFieldsAreIgnored() throws {
        let snapshot = try sanitizer.snapshot(
            from: fixture(named: "claude_status_line_null_unknown"),
            observedAt: 4
        )

        XCTAssertNil(snapshot.model)
        XCTAssertNil(snapshot.fiveHour)
        XCTAssertEqual(snapshot.sevenDay?.usedPercent, 12)
        XCTAssertNil(snapshot.sevenDay?.resetsAt)
    }

    func testRejectsInvalidPercentWithoutEchoingPayload() throws {
        let data = Data(#"{"rate_limits":{"five_hour":{"used_percentage":101,"resets_at":1900010000}}}"#.utf8)

        XCTAssertThrowsError(try sanitizer.snapshot(from: data, observedAt: 5)) { error in
            XCTAssertEqual(error as? ClaudeStatusLineSanitizationError, .invalidUsagePercent)
            XCTAssertFalse(error.localizedDescription.contains("101"))
        }
    }

    private func fixture(named name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }
}
