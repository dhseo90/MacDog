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

    func testFormatsUsageHealthSummaryWithoutRawErrorMessage() {
        let report = CodexUsageHealthReport(
            cacheFileURL: URL(fileURLWithPath: "/tmp/MacDog/usage.json"),
            cacheState: .error,
            cacheAgeSeconds: 180,
            cacheStaleAfterSeconds: 120,
            cacheHasReport: true,
            weeklyHistoryFileURL: URL(fileURLWithPath: "/tmp/MacDog/usage-weekly-history.json"),
            weeklyHistoryState: .ok,
            weeklySampleCount: 12,
            latestWeeklySampleResetsAt: 1_800_604_800,
            weeklyAppendState: .skipped,
            resetWindowHistoryFileURL: URL(fileURLWithPath: "/tmp/MacDog/usage-reset-window-history.json"),
            resetWindowHistoryState: .ok,
            resetWindowRecordCount: 3,
            latestResetWindowResetsAt: 1_800_604_800,
            resetWindowAppendState: .stored,
            resetWindowRetentionState: .ok,
            resetWindowRetentionLimit: 13,
            paceState: .projected,
            paceSampleCount: 2
        )

        let lines = CodexUsageDoctorFormatter().usageHealthLines(from: report)
        let output = lines.joined(separator: "\n")

        XCTAssertTrue(output.contains("Cache: error"))
        XCTAssertTrue(output.contains("age=180s"))
        XCTAssertTrue(output.contains("Weekly history: ok samples=12 append=skipped"))
        XCTAssertTrue(output.contains("Reset window history: ok records=3 append=stored retention=ok/13"))
        XCTAssertTrue(output.contains("Pace: projected samples=2"))
        XCTAssertFalse(output.localizedCaseInsensitiveContains("access_token"))
        XCTAssertFalse(output.localizedCaseInsensitiveContains("raw"))
        XCTAssertFalse(output.localizedCaseInsensitiveContains("session"))
    }

    func testFormatsUsageHealthNextStepForMissingCache() {
        let report = CodexUsageHealthReport(
            cacheFileURL: URL(fileURLWithPath: "/tmp/MacDog/usage.json"),
            cacheState: .missing,
            cacheAgeSeconds: nil,
            cacheStaleAfterSeconds: nil,
            cacheHasReport: false,
            weeklyHistoryFileURL: URL(fileURLWithPath: "/tmp/MacDog/usage-weekly-history.json"),
            weeklyHistoryState: .missing,
            weeklySampleCount: 0,
            latestWeeklySampleResetsAt: nil,
            resetWindowHistoryFileURL: URL(fileURLWithPath: "/tmp/MacDog/usage-reset-window-history.json"),
            resetWindowHistoryState: .missing,
            resetWindowRecordCount: 0,
            latestResetWindowResetsAt: nil
        )

        let lines = CodexUsageDoctorFormatter().usageHealthLines(from: report)
        let output = lines.joined(separator: "\n")

        XCTAssertTrue(output.contains("Next: run `codex-usage status --write-cache`"))
        XCTAssertFalse(output.localizedCaseInsensitiveContains("auth"))
        XCTAssertFalse(output.localizedCaseInsensitiveContains("session"))
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
