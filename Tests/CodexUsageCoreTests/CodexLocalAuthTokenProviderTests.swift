import Foundation
import XCTest
@testable import CodexUsageCore

final class CodexLocalAuthTokenProviderTests: XCTestCase {
    func testReadsCodexAuthStoreAndRefreshesAccessTokenInMemory() throws {
        let authURL = temporaryFileURL()
        try FileManager.default.createDirectory(
            at: authURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("""
        {
          "tokens": {
            "access_token": "old-memory-only-credential",
            "refresh_token": "refresh-memory-only-credential",
            "account_id": "acct_123"
          }
        }
        """.utf8).write(to: authURL)

        let provider = CodexLocalAuthTokenProvider(
            authFileURLs: [authURL],
            keychainReader: { nil },
            tokenRefresher: { refreshToken in
                XCTAssertEqual(refreshToken, "refresh-memory-only-credential")
                return "fresh-memory-only-credential"
            }
        )

        let tokens = try provider.readTokens()

        XCTAssertEqual(tokens.accessToken, "fresh-memory-only-credential")
        XCTAssertEqual(tokens.chatgptAccountId, "acct_123")
    }

    func testServiceFallsBackToLocalAuthWhenAppServerRefreshMethodIsUnavailable() throws {
        let response = try Self.rateLimitResponseWithResetCreditCount(1)
        let detailFetcher = StubResetCreditDetailsFetcherForLocalAuth(
            summary: RateLimitResetCreditsSummary(
                availableCount: 1,
                credits: [
                    RateLimitResetCredit(
                        id: "credit_1",
                        status: "available",
                        resetType: "manual",
                        expiresAt: "2026-07-10T08:00:00Z"
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
                throw CodexAppServerError.rpcError(
                    id: CodexAppServerRequestFactory.chatGPTAuthTokensRefreshRequestID,
                    message: "Invalid request: unknown variant `account/chatgptAuthTokens/refresh`"
                )
            },
            readLocalAuthTokens: {
                ChatGPTAuthTokensRefreshResponse(
                    accessToken: "local-memory-only-credential",
                    chatgptAccountId: "acct_local",
                    chatgptPlanType: nil
                )
            },
            resetCreditDetailsFetcher: detailFetcher,
            reportBuilder: CodexUsageReportBuilder(dateProvider: {
                Date(timeIntervalSince1970: 1_800_000_000)
            })
        )

        let report = try service.readReport()

        XCTAssertEqual(detailFetcher.lastAccountId, "acct_local")
        XCTAssertEqual(report.resetCredits?.credits.first?.expiresAt, "2026-07-10T08:00:00Z")
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

    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("auth.json")
    }
}

private final class StubResetCreditDetailsFetcherForLocalAuth: CodexResetCreditDetailsFetching {
    private let summary: RateLimitResetCreditsSummary
    private(set) var lastAccountId: String?

    init(summary: RateLimitResetCreditsSummary) {
        self.summary = summary
    }

    func fetch(accessToken: String, accountId: String?, timeout: TimeInterval) throws -> RateLimitResetCreditsSummary {
        XCTAssertEqual(accessToken, "local-memory-only-credential")
        lastAccountId = accountId
        return summary
    }
}
