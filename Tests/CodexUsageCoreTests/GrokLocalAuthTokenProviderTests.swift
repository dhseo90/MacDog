import Foundation
import XCTest
@testable import CodexUsageCore

final class GrokLocalAuthTokenProviderTests: XCTestCase {
    func testReadsAccessTokenFromTemporaryAuthFileOnly() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let authURL = directory.appendingPathComponent("auth.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(#"{"access_token":"fixture-token"}"#.utf8).write(to: authURL)

        let provider = GrokLocalAuthTokenProvider(authFileURLs: [authURL], refresher: nil)
        XCTAssertEqual(try provider.readAccessToken(), "fixture-token")
    }

    func testReadsNestedSignInKeyWithoutUsingAPIKeyEnvironment() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let authURL = directory.appendingPathComponent("auth.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(#"{"https://accounts.x.ai/sign-in":{"key":"fixture-sign-in-token"}}"#.utf8).write(to: authURL)

        let provider = GrokLocalAuthTokenProvider(authFileURLs: [authURL], refresher: nil)
        XCTAssertEqual(try provider.readAccessToken(), "fixture-sign-in-token")
    }

    func testReadsAuthXAIIssuerEntryKeyWithoutUsingRefreshToken() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let authURL = directory.appendingPathComponent("auth.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let payload = """
        {
          "https://auth.x.ai::00000000-0000-4000-8000-000000000001": {
            "key": "fixture-auth-xai-token",
            "refresh_token": "fixture-refresh-token",
            "expires_at": "2026-09-01T00:00:00.000Z"
          }
        }
        """
        try Data(payload.utf8).write(to: authURL)

        let refresher = RecordingRefresher()
        let provider = GrokLocalAuthTokenProvider(
            authFileURLs: [authURL],
            dateProvider: { ISO8601DateFormatter().date(from: "2026-08-22T00:00:00Z")! },
            lock: ImmediateLock(),
            refresher: refresher
        )
        XCTAssertEqual(try provider.readAccessToken(), "fixture-auth-xai-token")
        XCTAssertEqual(refresher.requests.count, 0)
    }

    func testMissingAuthStoreDoesNotUseXAIAPIKey() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-grok-auth-\(UUID().uuidString).json")
        let provider = GrokLocalAuthTokenProvider(authFileURLs: [missing], refresher: nil)
        XCTAssertThrowsError(try provider.readAccessToken()) { error in
            XCTAssertEqual(error as? GrokLocalAuthTokenProviderError, .noCredentialsFound)
        }
    }

    func testExpiredIssuerEntryRefreshesAndMergesWithoutDroppingOtherFields() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let authURL = directory.appendingPathComponent("auth.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let payload = """
        {
          "https://auth.x.ai::00000000-0000-4000-8000-000000000001": {
            "key": "fixture-old-access",
            "refresh_token": "fixture-old-refresh",
            "expires_at": "2020-01-01T00:00:00.000Z",
            "email": "fixture-user@example.test",
            "oidc_issuer": "https://auth.x.ai",
            "oidc_client_id": "00000000-0000-4000-8000-000000000001"
          },
          "xai::api_key": {
            "key": "fixture-other-scope",
            "auth_mode": "api_key"
          }
        }
        """
        try Data(payload.utf8).write(to: authURL)

        let refresher = RecordingRefresher(
            result: GrokOIDCRefreshTokens(
                accessToken: "fixture-new-access",
                refreshToken: "fixture-new-refresh",
                expiresIn: 21600
            )
        )
        let now = ISO8601DateFormatter().date(from: "2026-08-22T00:00:00Z")!
        let provider = GrokLocalAuthTokenProvider(
            authFileURLs: [authURL],
            dateProvider: { now },
            lock: ImmediateLock(),
            refresher: refresher
        )

        XCTAssertEqual(try provider.readAccessToken(), "fixture-new-access")
        XCTAssertEqual(refresher.requests.count, 1)
        XCTAssertEqual(refresher.requests.first?.refreshToken, "fixture-old-refresh")
        XCTAssertEqual(refresher.requests.first?.clientID, "00000000-0000-4000-8000-000000000001")
        XCTAssertEqual(refresher.requests.first?.issuer, "https://auth.x.ai")

        let stored = try JSONSerialization.jsonObject(with: Data(contentsOf: authURL)) as? [String: Any]
        let entry = stored?["https://auth.x.ai::00000000-0000-4000-8000-000000000001"] as? [String: Any]
        XCTAssertEqual(entry?["key"] as? String, "fixture-new-access")
        XCTAssertEqual(entry?["refresh_token"] as? String, "fixture-new-refresh")
        XCTAssertEqual(entry?["email"] as? String, "fixture-user@example.test")
        let other = stored?["xai::api_key"] as? [String: Any]
        XCTAssertEqual(other?["key"] as? String, "fixture-other-scope")
        let mode = try FileManager.default.attributesOfItem(atPath: authURL.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual((mode?.uint16Value ?? 0) & 0o777, 0o600)
    }

    func testLockUnavailableRereadsDiskWithoutCallingRefresher() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let authURL = directory.appendingPathComponent("auth.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let payload = """
        {
          "https://auth.x.ai::00000000-0000-4000-8000-000000000001": {
            "key": "fixture-expired-access",
            "refresh_token": "fixture-refresh-token",
            "expires_at": "2020-01-01T00:00:00.000Z"
          }
        }
        """
        try Data(payload.utf8).write(to: authURL)

        let refresher = RecordingRefresher()
        let provider = GrokLocalAuthTokenProvider(
            authFileURLs: [authURL],
            dateProvider: { ISO8601DateFormatter().date(from: "2026-08-22T00:00:00Z")! },
            lock: DeniedLock(),
            refresher: refresher
        )
        XCTAssertThrowsError(try provider.readAccessToken()) { error in
            XCTAssertEqual(error as? GrokLocalAuthTokenProviderError, .expiredAccessToken)
        }
        XCTAssertEqual(refresher.requests.count, 0)
        XCTAssertFalse(errorDescriptionContainsToken(GrokLocalAuthTokenProviderError.expiredAccessToken))
    }

    func testExpiredWithoutRefreshTokenDoesNotCallRefresher() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let authURL = directory.appendingPathComponent("auth.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let payload = """
        {
          "https://auth.x.ai::00000000-0000-4000-8000-000000000001": {
            "key": "fixture-expired-access",
            "expires_at": "2020-01-01T00:00:00.000Z"
          }
        }
        """
        try Data(payload.utf8).write(to: authURL)

        let refresher = RecordingRefresher()
        let provider = GrokLocalAuthTokenProvider(
            authFileURLs: [authURL],
            dateProvider: { ISO8601DateFormatter().date(from: "2026-08-22T00:00:00Z")! },
            lock: ImmediateLock(),
            refresher: refresher
        )
        XCTAssertThrowsError(try provider.readAccessToken()) { error in
            XCTAssertEqual(error as? GrokLocalAuthTokenProviderError, .expiredAccessToken)
        }
        XCTAssertEqual(refresher.requests.count, 0)
    }

    func testRejectingCurrentTokenForcesRefreshWhileStillValid() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let authURL = directory.appendingPathComponent("auth.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let payload = """
        {
          "https://auth.x.ai::00000000-0000-4000-8000-000000000001": {
            "key": "fixture-auth-xai-token",
            "refresh_token": "fixture-refresh-token",
            "expires_at": "2026-09-01T00:00:00.000Z",
            "oidc_issuer": "https://auth.x.ai",
            "oidc_client_id": "00000000-0000-4000-8000-000000000001"
          }
        }
        """
        try Data(payload.utf8).write(to: authURL)
        let refresher = RecordingRefresher(
            result: GrokOIDCRefreshTokens(
                accessToken: "fixture-forced-access",
                refreshToken: "fixture-forced-refresh",
                expiresIn: 21600
            )
        )
        let provider = GrokLocalAuthTokenProvider(
            authFileURLs: [authURL],
            dateProvider: { ISO8601DateFormatter().date(from: "2026-08-22T00:00:00Z")! },
            lock: ImmediateLock(),
            refresher: refresher
        )
        XCTAssertEqual(
            try provider.readAccessToken(rejecting: "fixture-auth-xai-token"),
            "fixture-forced-access"
        )
        XCTAssertEqual(refresher.requests.count, 1)
    }

    func testRefreshFailureDoesNotEmbedTokenMaterial() {
        XCTAssertFalse(errorDescriptionContainsToken(GrokLocalAuthTokenProviderError.refreshFailed))
        XCTAssertFalse(errorDescriptionContainsToken(GrokLocalAuthTokenProviderError.expiredAccessToken))
    }

    private func errorDescriptionContainsToken(_ error: GrokLocalAuthTokenProviderError) -> Bool {
        let text = error.localizedDescription
        return text.contains("fixture-")
            || text.contains("Bearer")
            || text.contains("refresh_token")
            || text.contains("access_token")
    }
}

private final class RecordingRefresher: GrokOIDCRefreshing, @unchecked Sendable {
    private(set) var requests: [GrokOIDCRefreshRequest] = []
    private let result: GrokOIDCRefreshTokens?

    init(result: GrokOIDCRefreshTokens? = nil) {
        self.result = result
    }

    func refresh(_ request: GrokOIDCRefreshRequest) throws -> GrokOIDCRefreshTokens {
        requests.append(request)
        guard let result else {
            throw GrokLocalAuthTokenProviderError.refreshFailed
        }
        return result
    }
}

private struct ImmediateLock: GrokAuthFileLocking {
    func withExclusiveLock<T>(
        adjacentTo _: URL,
        timeout _: TimeInterval,
        _ body: () throws -> T
    ) throws -> T? {
        try body()
    }
}

private struct DeniedLock: GrokAuthFileLocking {
    func withExclusiveLock<T>(
        adjacentTo _: URL,
        timeout _: TimeInterval,
        _: () throws -> T
    ) throws -> T? {
        nil
    }
}
