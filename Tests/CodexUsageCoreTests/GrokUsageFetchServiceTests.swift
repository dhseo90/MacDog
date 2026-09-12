import Foundation
import XCTest
@testable import CodexUsageCore

final class GrokUsageFetchServiceTests: XCTestCase {
    func testSuccessfulFetchWritesSanitizedWeeklySampleWithoutRawPayload() throws {
        let fixture = try Fixture()
        let transport = RecordingTransport(
            result: .success(Data(#"{"creditUsagePercent":42.5,"prepaidBalance":9,"access_token":"response-secret"}"#.utf8))
        )
        let service = GrokUsageFetchService(
            store: fixture.store,
            tokenProvider: GrokLocalAuthTokenProvider(authFileURLs: [fixture.authURL]),
            transport: transport
        )

        guard case .stored(let weekly) = try service.writeCache() else {
            return XCTFail("expected stored weekly window")
        }
        XCTAssertEqual(weekly.usedPercent, 42.5)
        XCTAssertEqual(try fixture.store.readHistory().samples.count, 1)
        let cacheText = try String(contentsOf: fixture.cacheURL)
        XCTAssertFalse(cacheText.contains("response-secret"))
        XCTAssertFalse(cacheText.contains("prepaidBalance"))
        XCTAssertFalse(cacheText.contains("fixture-token"))
        XCTAssertEqual(transport.authorizationHeaders, ["Bearer fixture-token"])
    }

    func testAuthFailureDoesNotCallTransportAndWritesSanitizedIssue() throws {
        let fixture = try Fixture()
        try FileManager.default.removeItem(at: fixture.authURL)
        let transport = RecordingTransport(result: .success(Data(#"{"creditUsagePercent":1}"#.utf8)))
        let service = GrokUsageFetchService(
            store: fixture.store,
            tokenProvider: GrokLocalAuthTokenProvider(authFileURLs: [fixture.authURL]),
            transport: transport
        )

        XCTAssertEqual(try service.writeCache(), .failed(code: "auth-unavailable"))
        XCTAssertTrue(transport.authorizationHeaders.isEmpty)
        XCTAssertEqual(try fixture.store.read().issue?.code, "auth-unavailable")
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.historyURL.path))
    }

    func testRequestFailurePreservesPreviousWeeklySample() throws {
        let fixture = try Fixture()
        let weekly = try XCTUnwrap(GrokUsageWeeklyWindow(usedPercent: 20, resetsAt: 1_900_600_000))
        _ = try fixture.store.record(weekly, at: 1_900_000_000)
        let transport = RecordingTransport(result: .failure(URLError(.timedOut)))
        let service = GrokUsageFetchService(
            store: fixture.store,
            tokenProvider: GrokLocalAuthTokenProvider(authFileURLs: [fixture.authURL]),
            transport: transport
        )

        XCTAssertEqual(try service.writeCache(), .failed(code: "request-failed"))
        XCTAssertEqual(try fixture.store.read().weekly?.usedPercent, 20)
        XCTAssertEqual(try fixture.store.readHistory().samples.count, 1)
    }

    func testUnauthorizedRetriesOnceAfterForcedRefresh() throws {
        let fixture = try Fixture.issuerAuth()
        let refresher = FetchRecordingRefresher(
            result: GrokOIDCRefreshTokens(
                accessToken: "fixture-retried-token",
                refreshToken: "fixture-new-refresh",
                expiresIn: 21600
            )
        )
        let transport = RecordingTransport(results: [
            .failure(GrokBillingTransportError.unauthorized),
            .success(Data(#"{"creditUsagePercent":12.5}"#.utf8))
        ])
        let service = GrokUsageFetchService(
            store: fixture.store,
            tokenProvider: GrokLocalAuthTokenProvider(
                authFileURLs: [fixture.authURL],
                lock: FetchImmediateLock(),
                refresher: refresher
            ),
            transport: transport
        )

        guard case .stored(let weekly) = try service.writeCache() else {
            return XCTFail("expected stored weekly window")
        }
        XCTAssertEqual(weekly.usedPercent, 12.5)
        XCTAssertEqual(refresher.requests.count, 1)
        XCTAssertEqual(
            transport.authorizationHeaders,
            ["Bearer fixture-token", "Bearer fixture-retried-token"]
        )
        let cacheText = try String(contentsOf: fixture.cacheURL)
        XCTAssertFalse(cacheText.contains("fixture-token"))
        XCTAssertFalse(cacheText.contains("fixture-retried-token"))
        XCTAssertFalse(cacheText.contains("fixture-refresh"))
    }

    func testSecondUnauthorizedDoesNotRefreshAgain() throws {
        let fixture = try Fixture.issuerAuth()
        let weekly = try XCTUnwrap(GrokUsageWeeklyWindow(usedPercent: 20, resetsAt: 1_900_600_000))
        _ = try fixture.store.record(weekly, at: 1_900_000_000)
        let refresher = FetchRecordingRefresher(
            result: GrokOIDCRefreshTokens(
                accessToken: "fixture-retried-token",
                refreshToken: "fixture-new-refresh",
                expiresIn: 21600
            )
        )
        let transport = RecordingTransport(results: [
            .failure(GrokBillingTransportError.unauthorized),
            .failure(GrokBillingTransportError.unauthorized)
        ])
        let service = GrokUsageFetchService(
            store: fixture.store,
            tokenProvider: GrokLocalAuthTokenProvider(
                authFileURLs: [fixture.authURL],
                lock: FetchImmediateLock(),
                refresher: refresher
            ),
            transport: transport
        )

        XCTAssertEqual(try service.writeCache(), .failed(code: "request-failed"))
        XCTAssertEqual(refresher.requests.count, 1)
        XCTAssertEqual(transport.authorizationHeaders.count, 2)
        XCTAssertEqual(try fixture.store.read().weekly?.usedPercent, 20)
        XCTAssertEqual(try fixture.store.readHistory().samples.count, 1)
    }

    func testExpiredAccessTokenWritesAuthExpiredWithoutTransport() throws {
        let fixture = try Fixture()
        try Data(#"""
        {
          "https://auth.x.ai::00000000-0000-4000-8000-000000000001": {
            "key": "fixture-expired-access",
            "expires_at": "2020-01-01T00:00:00.000Z"
          }
        }
        """#.utf8).write(to: fixture.authURL)
        let transport = RecordingTransport(result: .success(Data(#"{"creditUsagePercent":1}"#.utf8)))
        let service = GrokUsageFetchService(
            store: fixture.store,
            tokenProvider: GrokLocalAuthTokenProvider(
                authFileURLs: [fixture.authURL],
                lock: FetchImmediateLock(),
                refresher: FetchRecordingRefresher()
            ),
            transport: transport
        )

        XCTAssertEqual(try service.writeCache(), .failed(code: "auth-expired"))
        XCTAssertTrue(transport.authorizationHeaders.isEmpty)
        XCTAssertEqual(try fixture.store.read().issue?.code, "auth-expired")
    }

    private final class RecordingTransport: GrokBillingTransporting {
        private var results: [Result<Data, Error>]
        private(set) var authorizationHeaders: [String] = []

        init(result: Result<Data, Error>) {
            results = [result]
        }

        init(results: [Result<Data, Error>]) {
            self.results = results
        }

        func data(for request: URLRequest) throws -> Data {
            if let header = request.value(forHTTPHeaderField: "Authorization") {
                authorizationHeaders.append(header)
            }
            guard !results.isEmpty else {
                throw GrokBillingTransportError.failed
            }
            return try results.removeFirst().get()
        }
    }

    private final class FetchRecordingRefresher: GrokOIDCRefreshing, @unchecked Sendable {
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

    private struct FetchImmediateLock: GrokAuthFileLocking {
        func withExclusiveLock<T>(
            adjacentTo _: URL,
            timeout _: TimeInterval,
            _ body: () throws -> T
        ) throws -> T? {
            try body()
        }
    }

    private final class Fixture {
        let directory: URL
        let cacheURL: URL
        let historyURL: URL
        let authURL: URL
        let store: GrokUsageCacheStore

        init() throws {
            directory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            cacheURL = directory.appendingPathComponent("grok-usage.json")
            historyURL = directory.appendingPathComponent("grok-usage-history.json")
            authURL = directory.appendingPathComponent("auth.json")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data(#"{"access_token":"fixture-token"}"#.utf8).write(to: authURL)
            store = GrokUsageCacheStore(fileURL: cacheURL, historyFileURL: historyURL)
        }

        deinit {
            try? FileManager.default.removeItem(at: directory)
        }

        static func issuerAuth() throws -> Fixture {
            let fixture = try Fixture()
            let payload = """
            {
              "https://auth.x.ai::00000000-0000-4000-8000-000000000001": {
                "key": "fixture-token",
                "refresh_token": "fixture-refresh",
                "expires_at": "2027-12-31T00:00:00.000Z",
                "oidc_issuer": "https://auth.x.ai",
                "oidc_client_id": "00000000-0000-4000-8000-000000000001"
              }
            }
            """
            try Data(payload.utf8).write(to: fixture.authURL)
            return fixture
        }
    }
}
