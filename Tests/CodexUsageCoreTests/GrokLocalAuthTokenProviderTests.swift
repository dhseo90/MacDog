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

        let provider = GrokLocalAuthTokenProvider(authFileURLs: [authURL])
        XCTAssertEqual(try provider.readAccessToken(), "fixture-token")
    }

    func testReadsNestedSignInKeyWithoutUsingAPIKeyEnvironment() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let authURL = directory.appendingPathComponent("auth.json")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(#"{"https://accounts.x.ai/sign-in":{"key":"fixture-sign-in-token"}}"#.utf8).write(to: authURL)

        let provider = GrokLocalAuthTokenProvider(authFileURLs: [authURL])
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

        let provider = GrokLocalAuthTokenProvider(authFileURLs: [authURL])
        XCTAssertEqual(try provider.readAccessToken(), "fixture-auth-xai-token")
    }

    func testMissingAuthStoreDoesNotUseXAIAPIKey() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-grok-auth-\(UUID().uuidString).json")
        let provider = GrokLocalAuthTokenProvider(authFileURLs: [missing])
        XCTAssertThrowsError(try provider.readAccessToken()) { error in
            XCTAssertEqual(error as? GrokLocalAuthTokenProviderError, .noCredentialsFound)
        }
    }
}
