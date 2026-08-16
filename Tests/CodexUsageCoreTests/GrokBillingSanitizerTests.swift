import Foundation
import XCTest
@testable import CodexUsageCore

final class GrokBillingSanitizerTests: XCTestCase {
    func testExtractsWeeklyPercentAndDropsConsoleAndAuthFields() throws {
        let data = Data("""
        {
          "creditUsagePercent": 42.5,
          "billingCycle": "WEEKLY",
          "resetsAt": 1900600000,
          "prepaidBalance": 12.5,
          "monthlyLimit": 100,
          "onDemandUsed": 3,
          "subscription_tier": "supergrok",
          "access_token": "fixture-token"
        }
        """.utf8)
        let weekly = try GrokBillingSanitizer.weeklyWindow(from: data)
        XCTAssertEqual(weekly.usedPercent, 42.5)
        XCTAssertEqual(weekly.remainingPercent, 57.5)
        XCTAssertEqual(weekly.resetsAt, 1_900_600_000)
    }

    func testAcceptsJSONRPCResultWrapper() throws {
        let data = Data("""
        {"result":{"creditUsagePercent":10,"billingCycle":"weekly"}}
        """.utf8)
        let weekly = try GrokBillingSanitizer.weeklyWindow(from: data)
        XCTAssertEqual(weekly.usedPercent, 10)
        XCTAssertNil(weekly.resetsAt)
    }

    func testRejectsMonthlyCycleAndMissingPercent() {
        XCTAssertThrowsError(
            try GrokBillingSanitizer.weeklyWindow(from: Data(#"{"creditUsagePercent":10,"billingCycle":"MONTHLY"}"#.utf8))
        ) { error in
            XCTAssertEqual(error as? GrokBillingSanitizationError, .weeklyWindowMissing)
        }
        XCTAssertThrowsError(
            try GrokBillingSanitizer.weeklyWindow(from: Data(#"{"prepaidBalance":5}"#.utf8))
        ) { error in
            XCTAssertEqual(error as? GrokBillingSanitizationError, .weeklyWindowMissing)
        }
    }

    func testRejectsOversizedPayload() {
        let data = Data(repeating: 0x7B, count: GrokBillingSanitizer.maximumBillingBytes + 1)
        XCTAssertThrowsError(try GrokBillingSanitizer.weeklyWindow(from: data)) { error in
            XCTAssertEqual(error as? GrokBillingSanitizationError, .payloadTooLarge)
        }
    }
}
