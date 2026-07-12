import Foundation
import XCTest
@testable import CodexUsageCore

final class ClaudeUsagePrivacyTests: XCTestCase {
    func testSanitizedSnapshotDoesNotRetainSensitiveStatusLineFields() throws {
        let original = try fixture(named: "claude_status_line_sensitive")
        let snapshot = try ClaudeStatusLineSanitizer().snapshot(
            from: original,
            observedAt: 1_900_000_000
        )
        let encoded = try JSONEncoder().encode(snapshot)
        let output = try XCTUnwrap(String(data: encoded, encoding: .utf8))

        for forbidden in [
            "session-secret-123",
            "prompt-secret-456",
            "transcript-private.jsonl",
            "/Users/example/private-project",
            "private-repository",
            "Bearer secret-token",
            "refresh-token-secret",
            "cookie-secret"
        ] {
            XCTAssertFalse(output.contains(forbidden), "sanitized snapshot retained forbidden value: \(forbidden)")
        }
        XCTAssertTrue(output.contains("claude"))
        XCTAssertTrue(output.contains("33.5"))
    }

    func testSanitizedSnapshotDropsUnusedModelValuesIncludingSensitiveLookingText() throws {
        let input = Data(#"{"model":{"id":"/Users/private/token-secret","display_name":"Bearer session-secret"},"rate_limits":{"five_hour":{"used_percentage":12,"resets_at":1900010000}}}"#.utf8)
        let snapshot = try ClaudeStatusLineSanitizer().snapshot(from: input, observedAt: 1_900_000_000)
        let encoded = try JSONEncoder().encode(snapshot)
        let output = try XCTUnwrap(String(data: encoded, encoding: .utf8))

        XCTAssertFalse(output.contains("model"))
        XCTAssertFalse(output.contains("/Users/private"))
        XCTAssertFalse(output.contains("token-secret"))
        XCTAssertFalse(output.contains("session-secret"))
        XCTAssertTrue(output.contains("12"))
    }

    private func fixture(named name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }
}
