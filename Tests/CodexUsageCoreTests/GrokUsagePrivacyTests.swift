import Foundation
import XCTest
@testable import CodexUsageCore

final class GrokUsagePrivacyTests: XCTestCase {
    func testEncodedCacheOmitsForbiddenAuthAndBillingKeys() throws {
        let weekly = try XCTUnwrap(GrokUsageWeeklyWindow(usedPercent: 42.5, resetsAt: 1_900_600_000))
        let snapshot = GrokUsageCacheSnapshot(
            fetchedAt: 1_900_000_000,
            lastUsageObservedAt: 1_900_000_000,
            staleAfterSeconds: 180,
            weekly: weekly,
            issue: nil
        )
        let encoded = try XCTUnwrap(String(data: JSONEncoder().encode(snapshot), encoding: .utf8))

        for forbidden in [
            "Authorization",
            "Bearer",
            "access_token",
            "refresh_token",
            "cookie",
            "prepaidBalance",
            "monthlyLimit",
            "onDemandCap",
            "onDemandUsed",
            "subscription_tier",
            "fiveHour"
        ] {
            XCTAssertFalse(encoded.contains(forbidden), "cache retained forbidden key: \(forbidden)")
        }
        XCTAssertTrue(encoded.contains("unofficial-cli-billing"))
        XCTAssertTrue(encoded.contains("42.5"))
        XCTAssertTrue(encoded.contains("57.5"))
    }

    func testHistoryEncodeDoesNotKeepCallerSuppliedRemainingPercentDrift() throws {
        let sample = try XCTUnwrap(GrokUsageHistorySample(
            recordedAt: 1_900_000_000,
            usedPercent: 10,
            remainingPercent: 1,
            resetsAt: 1_900_600_000
        ))
        XCTAssertEqual(sample.remainingPercent, 90)
        let encoded = try XCTUnwrap(String(data: JSONEncoder().encode(sample), encoding: .utf8))
        XCTAssertFalse(encoded.contains("\"remainingPercent\":1"))
        XCTAssertTrue(encoded.contains("90"))
    }
}
