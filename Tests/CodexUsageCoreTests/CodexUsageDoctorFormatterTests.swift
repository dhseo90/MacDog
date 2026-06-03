import XCTest
@testable import CodexUsageCore

final class CodexUsageDoctorFormatterTests: XCTestCase {
    func testFormatsBucketInventoryWithFieldNamesOnly() {
        let inventory = CodexUsageFieldInventory(
            topLevelFields: ["rateLimits", "rateLimitsByLimitId"],
            buckets: [
                CodexUsageBucketFieldInventory(
                    key: "codex",
                    limitId: "codex",
                    fields: ["credits", "limitId", "primary", "secondary"],
                    primaryFields: ["resetsAt", "usedPercent", "windowDurationMins"],
                    secondaryFields: ["resetsAt", "usedPercent", "windowDurationMins"],
                    creditsFields: ["balance", "hasCredits", "unlimited"]
                ),
                CodexUsageBucketFieldInventory(
                    key: "codex_bengalfox",
                    limitId: "codex_bengalfox",
                    fields: ["limitId", "primary", "secondary"],
                    primaryFields: ["resetsAt", "usedPercent", "windowDurationMins"],
                    secondaryFields: [],
                    creditsFields: []
                )
            ]
        )

        let lines = CodexUsageDoctorFormatter().bucketInventoryLines(from: inventory)

        XCTAssertEqual(lines.first, "Buckets: codex, codex_bengalfox")
        XCTAssertTrue(lines.contains("Bucket codex: fields credits, limitId, primary, secondary"))
        XCTAssertTrue(lines.contains("Bucket codex primary fields: resetsAt, usedPercent, windowDurationMins"))
        XCTAssertFalse(lines.joined(separator: "\n").contains("secret"))
    }

    func testFormatsUnavailableBucketInventoryWhenEmpty() {
        let inventory = CodexUsageFieldInventory(
            topLevelFields: ["rateLimits", "rateLimitsByLimitId"],
            buckets: []
        )

        let lines = CodexUsageDoctorFormatter().bucketInventoryLines(from: inventory)

        XCTAssertEqual(lines, ["Buckets: unavailable"])
    }

    func testRedactsSensitiveBucketIdentifiersInUserFacingOutput() {
        let inventory = CodexUsageFieldInventory(
            topLevelFields: ["rateLimits", "rateLimitsByLimitId"],
            buckets: [
                CodexUsageBucketFieldInventory(
                    key: "codex_token_window",
                    limitId: "auth-header-window",
                    fields: ["credits", "limitId", "primary", "secondary"],
                    primaryFields: ["resetsAt", "usedPercent", "windowDurationMins"],
                    secondaryFields: ["resetsAt", "usedPercent", "windowDurationMins"],
                    creditsFields: []
                ),
                CodexUsageBucketFieldInventory(
                    key: "session_bucket",
                    limitId: "session_bucket",
                    fields: ["limitId", "primary", "secondary"],
                    primaryFields: [],
                    secondaryFields: [],
                    creditsFields: []
                )
            ]
        )

        let lines = CodexUsageDoctorFormatter().bucketInventoryLines(from: inventory)
        let output = lines.joined(separator: "\n")

        XCTAssertTrue(output.contains("<redacted-sensitive-field>"))
        XCTAssertFalse(output.contains("codex_token_window"))
        XCTAssertFalse(output.contains("auth-header-window"))
        XCTAssertFalse(output.contains("session_bucket"))
        XCTAssertFalse(output.contains("token"))
        XCTAssertFalse(output.contains("auth-header"))
        XCTAssertFalse(output.contains("session"))
    }
}
