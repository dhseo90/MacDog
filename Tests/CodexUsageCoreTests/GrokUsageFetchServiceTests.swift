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

    private final class RecordingTransport: GrokBillingTransporting {
        let result: Result<Data, Error>
        private(set) var authorizationHeaders: [String] = []

        init(result: Result<Data, Error>) {
            self.result = result
        }

        func data(for request: URLRequest) throws -> Data {
            if let header = request.value(forHTTPHeaderField: "Authorization") {
                authorizationHeaders.append(header)
            }
            return try result.get()
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
    }
}
