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

    func testSanitizedModelStringsAreTrimmedAndBounded() throws {
        let longName = String(repeating: "x", count: 300)
        let model = ClaudeStatusLineModel(
            id: "  claude\n-model\u{001B}[31m  ",
            displayName: longName
        )

        XCTAssertEqual(model.id, "claude-model[31m")
        XCTAssertEqual(model.displayName?.count, 160)
    }

    private func fixture(named name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }
}
