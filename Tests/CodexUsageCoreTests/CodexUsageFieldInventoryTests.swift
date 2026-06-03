import XCTest
@testable import CodexUsageCore

final class CodexUsageFieldInventoryTests: XCTestCase {
    func testBuildsInventoryFromJSONRPCFixtureEnvelope() throws {
        let fixture = try JSONSerialization.jsonObject(with: loadFixtureData())
        let envelope: [String: Any] = [
            "id": CodexAppServerRequestFactory.rateLimitReadRequestID,
            "result": fixture
        ]
        let data = try JSONSerialization.data(withJSONObject: envelope)

        let inventory = try CodexUsageFieldInventory.make(fromJSONRPCResponseData: data)

        XCTAssertEqual(inventory.topLevelFields, ["rateLimits", "rateLimitsByLimitId"])
        XCTAssertEqual(inventory.buckets.map(\.key), ["codex", "codex_bengalfox"])
        XCTAssertEqual(inventory.buckets.map(\.limitId), ["codex", "codex_bengalfox"])
        XCTAssertEqual(
            inventory.buckets.first?.fields,
            ["credits", "limitId", "limitName", "planType", "primary", "rateLimitReachedType", "secondary"]
        )
        XCTAssertEqual(inventory.buckets.first?.primaryFields, ["resetsAt", "usedPercent", "windowDurationMins"])
        XCTAssertEqual(inventory.buckets.first?.secondaryFields, ["resetsAt", "usedPercent", "windowDurationMins"])
        XCTAssertEqual(inventory.buckets.first?.creditsFields, ["balance", "hasCredits", "unlimited"])
    }

    func testKeepsAdditiveSafeFieldsAsFieldNamesOnly() throws {
        let json = """
        {
          "id": 2,
          "result": {
            "rateLimits": {
              "limitId": "codex",
              "limitName": "Codex",
              "primary": { "usedPercent": 12, "windowDurationMins": 300, "resetsAt": 1780000000, "safeFutureWindowField": "ignored-value" },
              "secondary": { "usedPercent": 34, "windowDurationMins": 10080, "resetsAt": 1780500000 },
              "credits": { "hasCredits": false, "unlimited": false, "balance": "0" },
              "planType": "pro",
              "rateLimitReachedType": null,
              "safeFutureBucketField": { "nested": true }
            },
            "safeFutureTopLevelField": "ignored-value"
          }
        }
        """

        let inventory = try CodexUsageFieldInventory.make(fromJSONRPCResponseData: Data(json.utf8))

        XCTAssertTrue(inventory.topLevelFields.contains("safeFutureTopLevelField"))
        XCTAssertTrue(inventory.buckets[0].fields.contains("safeFutureBucketField"))
        XCTAssertTrue(inventory.buckets[0].primaryFields.contains("safeFutureWindowField"))
    }

    func testRedactsSensitiveLookingFieldNamesAndNeverIncludesValues() throws {
        let json = """
        {
          "id": 2,
          "result": {
            "rateLimits": {
              "limitId": "codex",
              "limitName": "Codex",
              "primary": { "usedPercent": 12, "windowDurationMins": 300, "resetsAt": 1780000000 },
              "secondary": { "usedPercent": 34, "windowDurationMins": 10080, "resetsAt": 1780500000 },
              "credits": { "hasCredits": false, "unlimited": false, "balance": "0" },
              "planType": "pro",
              "rateLimitReachedType": null,
              "access_token": "secret-token-value",
              "cookie": "secret-cookie-value"
            }
          }
        }
        """

        let inventory = try CodexUsageFieldInventory.make(fromJSONRPCResponseData: Data(json.utf8))
        let summary = inventory.redactedSummaryLines.joined(separator: "\\n")

        XCTAssertTrue(inventory.buckets[0].fields.contains("<redacted-sensitive-field>"))
        XCTAssertFalse(summary.contains("access_token"))
        XCTAssertFalse(summary.contains("cookie"))
        XCTAssertFalse(summary.contains("secret-token-value"))
        XCTAssertFalse(summary.contains("secret-cookie-value"))
    }

    func testRedactsHyphenatedSensitiveFieldNames() throws {
        let json = """
        {
          "id": 2,
          "result": {
            "rateLimits": {
              "limitId": "codex",
              "limitName": "Codex",
              "primary": { "usedPercent": 12, "windowDurationMins": 300, "resetsAt": 1780000000 },
              "secondary": { "usedPercent": 34, "windowDurationMins": 10080, "resetsAt": 1780500000 },
              "credits": { "hasCredits": false, "unlimited": false, "balance": "0" },
              "planType": "pro",
              "rateLimitReachedType": null,
              "access-token": "secret-hyphen-value"
            }
          }
        }
        """

        let inventory = try CodexUsageFieldInventory.make(fromJSONRPCResponseData: Data(json.utf8))
        let summary = inventory.redactedSummaryLines.joined(separator: "\\n")

        XCTAssertTrue(inventory.buckets[0].fields.contains("<redacted-sensitive-field>"))
        XCTAssertFalse(summary.contains("access-token"))
        XCTAssertFalse(summary.contains("secret-hyphen-value"))
    }

    func testRedactsCommonSensitiveFieldNameVariants() throws {
        let rateLimits: [String: Any] = [
            "limitId": "codex",
            "limitName": "Codex",
            "primary": ["usedPercent": 12, "windowDurationMins": 300, "resetsAt": 1780000000],
            "secondary": ["usedPercent": 34, "windowDurationMins": 10080, "resetsAt": 1780500000],
            "credits": ["hasCredits": false, "unlimited": false, "balance": "0"],
            "planType": "pro",
            "rateLimitReachedType": NSNull(),
            "accessToken": "secret-access-token",
            "refreshToken": "secret-refresh-token",
            "clientSecret": "secret-client-secret",
            "apiKey": "secret-api-key",
            "token": "secret-token",
            "authHeader": "secret-auth-header",
            "safeField": "kept"
        ]

        let payload: [String: Any] = [
            "id": 2,
            "result": [
                "rateLimits": rateLimits
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)

        let inventory = try CodexUsageFieldInventory.make(fromJSONRPCResponseData: data)
        let summary = inventory.redactedSummaryLines.joined(separator: "\\n")

        XCTAssertTrue(inventory.buckets[0].fields.contains("<redacted-sensitive-field>"))
        XCTAssertFalse(summary.contains("accessToken"))
        XCTAssertFalse(summary.contains("refreshToken"))
        XCTAssertFalse(summary.contains("clientSecret"))
        XCTAssertFalse(summary.contains("apiKey"))
        XCTAssertFalse(summary.contains("token"))
        XCTAssertFalse(summary.contains("authHeader"))
        XCTAssertFalse(summary.contains("secret-access-token"))
        XCTAssertFalse(summary.contains("secret-refresh-token"))
        XCTAssertFalse(summary.contains("secret-client-secret"))
        XCTAssertFalse(summary.contains("secret-api-key"))
        XCTAssertFalse(summary.contains("secret-token"))
        XCTAssertFalse(summary.contains("secret-auth-header"))
    }

    func testSensitiveBucketIdentifiersArePreservedInternallyButRedactedFromSummary() throws {
        let json = """
        {
          "id": 2,
          "result": {
            "rateLimitsByLimitId": {
              "codex_token_window": {
                "limitId": "codex_token_window",
                "limitName": "Codex token window",
                "primary": { "usedPercent": 12, "windowDurationMins": 300, "resetsAt": 1780000000 },
                "secondary": { "usedPercent": 34, "windowDurationMins": 10080, "resetsAt": 1780500000 },
                "credits": { "hasCredits": false, "unlimited": false, "balance": "0" },
                "planType": "pro",
                "rateLimitReachedType": null
              }
            }
          }
        }
        """

        let inventory = try CodexUsageFieldInventory.make(fromJSONRPCResponseData: Data(json.utf8))
        let summary = inventory.redactedSummaryLines.joined(separator: "\\n")

        XCTAssertEqual(inventory.buckets.map(\.key), ["codex_token_window"])
        XCTAssertEqual(inventory.buckets.map(\.limitId), ["codex_token_window"])
        XCTAssertEqual(
            inventory.buckets[0].fields,
            ["credits", "limitId", "limitName", "planType", "primary", "rateLimitReachedType", "secondary"]
        )
        XCTAssertTrue(summary.contains("<redacted-sensitive-field>"))
        XCTAssertFalse(summary.contains("codex_token_window"))
        XCTAssertFalse(summary.contains("token"))
    }

    func testRedactsAuthHeaderVariants() throws {
        let json = """
        {
          "id": 2,
          "result": {
            "rateLimits": {
              "limitId": "codex",
              "limitName": "Codex",
              "primary": { "usedPercent": 12, "windowDurationMins": 300, "resetsAt": 1780000000 },
              "secondary": { "usedPercent": 34, "windowDurationMins": 10080, "resetsAt": 1780500000 },
              "credits": { "hasCredits": false, "unlimited": false, "balance": "0" },
              "planType": "pro",
              "rateLimitReachedType": null,
              "auth-header": "secret-auth-header",
              "auth_header": "secret-auth-header-2"
            }
          }
        }
        """

        let inventory = try CodexUsageFieldInventory.make(fromJSONRPCResponseData: Data(json.utf8))
        let summary = inventory.redactedSummaryLines.joined(separator: "\\n")

        XCTAssertFalse(summary.contains("auth-header"))
        XCTAssertFalse(summary.contains("auth_header"))
        XCTAssertFalse(summary.contains("secret-auth-header"))
        XCTAssertFalse(summary.contains("secret-auth-header-2"))
        XCTAssertTrue(inventory.buckets[0].fields.contains("<redacted-sensitive-field>"))
    }

    func testLegacyRateLimitsFallbackPreservesKeyAndLimitId() throws {
        let json = """
        {
          "id": 2,
          "result": {
            "rateLimits": {
              "limitId": "legacy_token_bucket",
              "limitName": "Legacy",
              "primary": { "usedPercent": 12, "windowDurationMins": 300, "resetsAt": 1780000000 },
              "secondary": { "usedPercent": 34, "windowDurationMins": 10080, "resetsAt": 1780500000 },
              "credits": { "hasCredits": false, "unlimited": false, "balance": "0" },
              "planType": "pro",
              "rateLimitReachedType": null
            }
          }
        }
        """

        let inventory = try CodexUsageFieldInventory.make(fromJSONRPCResponseData: Data(json.utf8))
        let summary = inventory.redactedSummaryLines.joined(separator: "\\n")

        XCTAssertEqual(inventory.buckets.map(\.key), ["legacy_token_bucket"])
        XCTAssertEqual(inventory.buckets.map(\.limitId), ["legacy_token_bucket"])
        XCTAssertTrue(summary.contains("<redacted-sensitive-field>"))
        XCTAssertFalse(summary.contains("legacy_token_bucket"))
        XCTAssertFalse(summary.contains("token"))
    }

    func testMissingResultThrowsInventoryError() {
        let json = "{\"id\":2,\"error\":{\"message\":\"unauthorized\"}}"

        XCTAssertThrowsError(
            try CodexUsageFieldInventory.make(fromJSONRPCResponseData: Data(json.utf8))
        ) { error in
            XCTAssertEqual(error as? CodexUsageFieldInventoryError, .missingResult)
        }
    }

    private func loadFixtureData() throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: "rate_limits_response",
            withExtension: "json"
        ))
        return try Data(contentsOf: url)
    }
}
