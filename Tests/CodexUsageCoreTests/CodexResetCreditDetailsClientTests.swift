import Foundation
import XCTest
@testable import CodexUsageCore

final class CodexResetCreditDetailsClientTests: XCTestCase {
    func testFetchDecodesAvailableCreditsAndExpiryDatesFromBackendDetailResponse() throws {
        let credential = "memory-only-credential"
        var capturedRequest: URLRequest?
        let client = CodexResetCreditDetailsClient { request in
            capturedRequest = request
            let data = Data("""
            {
              "available_count": 3,
              "credits": [
                {
                  "id": "credit_1",
                  "status": "available",
                  "reset_type": "manual",
                  "expires_at": "2026-07-10T08:00:00Z"
                },
                {
                  "id": "credit_2",
                  "status": "available",
                  "reset_type": "manual",
                  "expires_at": "2026-07-11T08:00:00Z"
                },
                {
                  "id": "credit_3",
                  "status": "available",
                  "reset_type": "manual",
                  "expires_at": "2026-07-12T08:00:00Z"
                }
              ]
            }
            """.utf8)
            return (data, HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!)
        }

        let summary = try client.fetch(
            accessToken: credential,
            accountId: "acct_123",
            timeout: 7
        )

        XCTAssertEqual(summary.availableCount, 3)
        XCTAssertEqual(summary.credits.count, 3)
        XCTAssertEqual(summary.credits.map(\.expiresAt), [
            "2026-07-10T08:00:00Z",
            "2026-07-11T08:00:00Z",
            "2026-07-12T08:00:00Z"
        ])

        let request = try XCTUnwrap(capturedRequest)
        XCTAssertEqual(request.url?.absoluteString, "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits")
        XCTAssertEqual(request.timeoutInterval, 7)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(credential)")
        XCTAssertEqual(request.value(forHTTPHeaderField: "ChatGPT-Account-Id"), "acct_123")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
    }

    func testReadReportEnrichesResetCreditsWithExpiryDetails() throws {
        let response = try Self.rateLimitResponseWithResetCreditCount(3)
        let detailFetcher = StubResetCreditDetailsFetcher(
            summary: RateLimitResetCreditsSummary(
                availableCount: 3,
                credits: [
                    RateLimitResetCredit(
                        id: "credit_1",
                        status: "available",
                        resetType: "manual",
                        expiresAt: "2026-07-10T08:00:00Z"
                    ),
                    RateLimitResetCredit(
                        id: "credit_2",
                        status: "available",
                        resetType: "manual",
                        expiresAt: "2026-07-11T08:00:00Z"
                    ),
                    RateLimitResetCredit(
                        id: "credit_3",
                        status: "available",
                        resetType: "manual",
                        expiresAt: "2026-07-12T08:00:00Z"
                    )
                ]
            )
        )
        let service = CodexUsageService(
            readRateLimits: { response },
            readRateLimitDiagnostic: {
                CodexAppServerRateLimitDiagnostic(
                    response: response,
                    fieldInventory: CodexUsageFieldInventory(topLevelFields: [], buckets: [])
                )
            },
            refreshAuthTokens: {
                ChatGPTAuthTokensRefreshResponse(
                    accessToken: "memory-only-credential",
                    chatgptAccountId: "acct_123",
                    chatgptPlanType: nil
                )
            },
            resetCreditDetailsFetcher: detailFetcher,
            reportBuilder: CodexUsageReportBuilder(dateProvider: {
                Date(timeIntervalSince1970: 1_800_000_000)
            })
        )

        let report = try service.readReport()

        XCTAssertEqual(detailFetcher.fetchCount, 1)
        XCTAssertEqual(detailFetcher.lastAccountId, "acct_123")
        XCTAssertEqual(report.resetCredits?.availableCount, 3)
        XCTAssertEqual(report.resetCredits?.credits.count, 3)
        XCTAssertEqual(report.resetCredits?.credits.last?.expiresAt, "2026-07-12T08:00:00Z")
    }

    func testJSONReportDoesNotExposeResetCreditIdentifiersOrMarketingCopy() throws {
        let response = try Self.rateLimitResponseWithResetCreditCount(1)
        let report = try CodexUsageReportBuilder(dateProvider: {
            Date(timeIntervalSince1970: 1_800_000_000)
        })
        .build(from: response)
        .replacingResetCredits(
            RateLimitResetCreditsSummary(
                availableCount: 1,
                credits: [
                    RateLimitResetCredit(
                        id: "RateLimitResetCredit_sensitive",
                        status: "available",
                        resetType: "codex_rate_limits",
                        expiresAt: "2026-07-10T08:00:00Z",
                        title: "Full reset",
                        description: "Thanks for using Codex!"
                    )
                ]
            )
        )

        let data = try CodexUsageFormatter().json(from: report)
        let text = String(decoding: data, as: UTF8.self)

        XCTAssertTrue(text.contains("expiresAt"))
        XCTAssertTrue(text.contains("status"))
        XCTAssertTrue(text.contains("resetType"))
        XCTAssertFalse(text.contains("RateLimitResetCredit_sensitive"))
        XCTAssertFalse(text.contains("Full reset"))
        XCTAssertFalse(text.contains("Thanks for using Codex"))
    }

    private static func rateLimitResponseWithResetCreditCount(_ count: Int) throws -> RateLimitsResponse {
        let url = try XCTUnwrap(
            Bundle.module.url(
                forResource: "rate_limits_response",
                withExtension: "json"
            )
        )
        let data = try Data(contentsOf: url)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["rateLimitResetCredits"] = ["availableCount": count]
        let updated = try JSONSerialization.data(withJSONObject: object)
        return try JSONDecoder().decode(RateLimitsResponse.self, from: updated)
    }
}

private final class StubResetCreditDetailsFetcher: CodexResetCreditDetailsFetching {
    private let summary: RateLimitResetCreditsSummary
    private(set) var fetchCount = 0
    private(set) var lastAccountId: String?

    init(summary: RateLimitResetCreditsSummary) {
        self.summary = summary
    }

    func fetch(accessToken: String, accountId: String?, timeout: TimeInterval) throws -> RateLimitResetCreditsSummary {
        fetchCount += 1
        lastAccountId = accountId
        XCTAssertFalse(accessToken.isEmpty)
        XCTAssertGreaterThan(timeout, 0)
        return summary
    }
}
