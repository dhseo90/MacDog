import XCTest
@testable import CodexUsageCore

final class RateLimitModelsTests: XCTestCase {
    func testDecodesCodexRateLimitBucket() throws {
        let data = try loadFixtureData()
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

    func testFixtureKeepsExpectedRateLimitResponseSchema() throws {
        let data = try loadFixtureData()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertNotNil(object["rateLimits"])
        XCTAssertNotNil(object["rateLimitsByLimitId"])

        let rateLimitsByLimitId = try XCTUnwrap(object["rateLimitsByLimitId"] as? [String: Any])
        let codexBucket = try XCTUnwrap(rateLimitsByLimitId["codex"] as? [String: Any])
        try assertBucketSchema(codexBucket)
        XCTAssertNotNil(rateLimitsByLimitId["codex_bengalfox"])
    }

    func testDecodesRateLimitsJSONRPCEnvelope() throws {
        let fixture = try JSONSerialization.jsonObject(with: loadFixtureData())
        let envelope: [String: Any] = [
            "id": CodexAppServerRequestFactory.rateLimitReadRequestID,
            "result": fixture
        ]
        let data = try JSONSerialization.data(withJSONObject: envelope)

        let response = try JSONDecoder().decode(JSONRPCResponse<RateLimitsResponse>.self, from: data)

        XCTAssertEqual(response.id, CodexAppServerRequestFactory.rateLimitReadRequestID)
        XCTAssertNil(response.error)
        XCTAssertEqual(response.result?.codexBucket.limitId, "codex")
    }

    func testCodexBucketFallsBackToLegacyTopLevelRateLimits() {
        let legacyBucket = RateLimitSnapshot(
            limitId: "codex",
            limitName: nil,
            primary: RateLimitWindow(usedPercent: 20, windowDurationMins: 300, resetsAt: nil),
            secondary: RateLimitWindow(usedPercent: 55, windowDurationMins: 10_080, resetsAt: nil),
            credits: nil,
            planType: "pro",
            rateLimitReachedType: nil
        )
        let response = RateLimitsResponse(rateLimits: legacyBucket, rateLimitsByLimitId: nil)

        XCTAssertEqual(response.codexBucket.limitId, "codex")
        XCTAssertEqual(response.codexBucket.fiveHourWindow?.remainingPercent, 80)
        XCTAssertEqual(response.codexBucket.weeklyWindow?.remainingPercent, 45)
    }

    func testCodexBucketFallsBackWhenBucketMapOmitsCodex() {
        let legacyBucket = RateLimitSnapshot(
            limitId: "codex",
            limitName: nil,
            primary: RateLimitWindow(usedPercent: 21, windowDurationMins: 300, resetsAt: nil),
            secondary: RateLimitWindow(usedPercent: 43, windowDurationMins: 10_080, resetsAt: nil),
            credits: nil,
            planType: "pro",
            rateLimitReachedType: nil
        )
        let advancedBucket = RateLimitSnapshot(
            limitId: "codex_bengalfox",
            limitName: nil,
            primary: RateLimitWindow(usedPercent: 1, windowDurationMins: 300, resetsAt: nil),
            secondary: RateLimitWindow(usedPercent: 2, windowDurationMins: 10_080, resetsAt: nil),
            credits: nil,
            planType: "pro",
            rateLimitReachedType: nil
        )
        let response = RateLimitsResponse(
            rateLimits: legacyBucket,
            rateLimitsByLimitId: ["codex_bengalfox": advancedBucket]
        )

        XCTAssertEqual(response.codexBucket.limitId, "codex")
        XCTAssertEqual(response.codexBucket.fiveHourWindow?.usedPercent, 21)
        XCTAssertEqual(response.codexBucket.weeklyWindow?.usedPercent, 43)
    }

    func testDecodesAdditiveProtocolDriftFieldsWithoutChangingContract() throws {
        let json = """
        {
          "rateLimits": {
            "limitId": "legacy",
            "limitName": "Legacy",
            "primary": { "usedPercent": 20, "windowDurationMins": 300, "resetsAt": 1780000000 },
            "secondary": { "usedPercent": 40, "windowDurationMins": 10080, "resetsAt": 1780500000 },
            "credits": { "hasCredits": false, "unlimited": false, "balance": "0" },
            "planType": "pro",
            "rateLimitReachedType": null
          },
          "rateLimitsByLimitId": {
            "codex": {
              "limitId": "codex",
              "limitName": "Codex",
              "primary": {
                "usedPercent": 12,
                "windowDurationMins": 300,
                "resetsAt": 1780000000,
                "futureServerField": "ignored"
              },
              "secondary": { "usedPercent": 34, "windowDurationMins": 10080, "resetsAt": 1780500000 },
              "credits": { "hasCredits": false, "unlimited": false, "balance": "0" },
              "planType": "pro",
              "rateLimitReachedType": null,
              "futureBucketMetadata": { "ignored": true }
            }
          },
          "futureTopLevelField": "ignored"
        }
        """

        let response = try JSONDecoder().decode(RateLimitsResponse.self, from: Data(json.utf8))

        XCTAssertEqual(response.codexBucket.limitId, "codex")
        XCTAssertEqual(response.codexBucket.fiveHourWindow?.usedPercent, 12)
        XCTAssertEqual(response.codexBucket.weeklyWindow?.usedPercent, 34)
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

    private func loadFixtureData() throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: "rate_limits_response",
            withExtension: "json"
        ))
        return try Data(contentsOf: url)
    }

    private func assertBucketSchema(_ bucket: [String: Any]) throws {
        XCTAssertTrue(bucket.keys.contains("limitId"))
        XCTAssertTrue(bucket.keys.contains("limitName"))
        XCTAssertTrue(bucket.keys.contains("primary"))
        XCTAssertTrue(bucket.keys.contains("secondary"))
        XCTAssertTrue(bucket.keys.contains("credits"))
        XCTAssertTrue(bucket.keys.contains("planType"))
        XCTAssertTrue(bucket.keys.contains("rateLimitReachedType"))

        let primary = try XCTUnwrap(bucket["primary"] as? [String: Any])
        let secondary = try XCTUnwrap(bucket["secondary"] as? [String: Any])
        assertWindowSchema(primary, expectedDuration: 300)
        assertWindowSchema(secondary, expectedDuration: 10_080)

        let credits = try XCTUnwrap(bucket["credits"] as? [String: Any])
        XCTAssertTrue(credits.keys.contains("hasCredits"))
        XCTAssertTrue(credits.keys.contains("unlimited"))
        XCTAssertTrue(credits.keys.contains("balance"))
    }

    private func assertWindowSchema(_ window: [String: Any], expectedDuration: Int) {
        XCTAssertTrue(window.keys.contains("usedPercent"))
        XCTAssertEqual(window["windowDurationMins"] as? Int, expectedDuration)
        XCTAssertTrue(window.keys.contains("resetsAt"))
    }
}
