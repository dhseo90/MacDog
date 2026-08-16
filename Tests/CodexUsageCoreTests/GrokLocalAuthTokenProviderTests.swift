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

    func testMissingAuthStoreDoesNotUseXAIAPIKey() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-grok-auth-\(UUID().uuidString).json")
        let provider = GrokLocalAuthTokenProvider(authFileURLs: [missing])
        XCTAssertThrowsError(try provider.readAccessToken()) { error in
            XCTAssertEqual(error as? GrokLocalAuthTokenProviderError, .noCredentialsFound)
        }
    }
}
