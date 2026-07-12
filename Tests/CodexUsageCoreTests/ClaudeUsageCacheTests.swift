import Foundation
import XCTest
@testable import CodexUsageCore

final class ClaudeUsageCacheTests: XCTestCase {
    func testDefaultFilesAreSeparatedFromCodexFiles() {
        XCTAssertEqual(ClaudeUsageCacheStore.defaultFileURL().lastPathComponent, "claude-usage.json")
        XCTAssertEqual(
            ClaudeUsageHistoryStore.defaultFileURL(
                adjacentToCacheFileURL: ClaudeUsageCacheStore.defaultFileURL()
            ).lastPathComponent,
            "claude-usage-history.json"
        )
        XCTAssertNotEqual(ClaudeUsageCacheStore.defaultFileURL(), CodexUsageCacheStore.defaultFileURL())
    }

    func testSuccessfulEventWritesAtomicCacheAndHistory() throws {
        let fixture = try Fixture()
        var writes: [(String, Data.WritingOptions)] = []
        let store = fixture.store(dataWriter: { data, url, options in
            writes.append((url.lastPathComponent, options))
            try data.write(to: url, options: options)
        })

        let result = try store.ingest(statusLineData: try fixture.data(named: "claude_status_line_full"))

        guard case .stored = result else { return XCTFail("expected stored result") }
        XCTAssertEqual(try store.read().status(now: fixture.now), .available)
        XCTAssertEqual(try store.readHistory().samples.count, 2)
        XCTAssertEqual(Set(writes.map(\.0)), ["claude-usage.json", "claude-usage-history.json"])
        XCTAssertTrue(writes.allSatisfy { $0.1.contains(.atomic) })
    }

    func testMissingRateLimitsPreservesLastUsageWithoutAdvancingFreshness() throws {
        let fixture = try Fixture()
        let store = fixture.store()
        _ = try store.ingest(statusLineData: try fixture.data(named: "claude_status_line_full"))

        fixture.timestamp += 60
        _ = try store.ingest(statusLineData: try fixture.data(named: "claude_status_line_missing_rate_limits"))
        let cache = try store.read()

        XCTAssertEqual(cache.lastEventAt, fixture.timestamp)
        XCTAssertEqual(cache.lastUsageObservedAt, fixture.initialTimestamp)
        XCTAssertEqual(cache.usage?.fiveHour?.usedPercent, 42.5)
        XCTAssertEqual(try store.readHistory().samples.count, 2)
    }

    func testMalformedEventPreservesLastGoodUsageWithSanitizedIssueAndRecovers() throws {
        let fixture = try Fixture()
        let store = fixture.store()
        _ = try store.ingest(statusLineData: try fixture.data(named: "claude_status_line_full"))

        fixture.timestamp += 60
        let secret = Data("{not-json-session-secret}".utf8)
        XCTAssertEqual(
            try store.ingest(statusLineData: secret),
            .failed(code: "status_line_decode_failed")
        )
        var cache = try store.read()
        XCTAssertEqual(cache.status(now: fixture.now), .error)
        XCTAssertEqual(cache.issue?.code, "status_line_decode_failed")
        XCTAssertEqual(cache.usage?.sevenDay?.usedPercent, 61)
        XCTAssertFalse(try String(contentsOf: fixture.cacheURL).contains("session-secret"))

        fixture.timestamp += 60
        _ = try store.ingest(statusLineData: try fixture.data(named: "claude_status_line_five_hour_only"))
        cache = try store.read()
        XCTAssertNil(cache.issue)
        XCTAssertEqual(cache.status(now: fixture.now), .partial)
    }

    func testStaleUsesLastUsageObservationNotLastEvent() throws {
        let fixture = try Fixture()
        let store = fixture.store()
        _ = try store.ingest(statusLineData: try fixture.data(named: "claude_status_line_full"), staleAfterSeconds: 120)
        fixture.timestamp += 121
        _ = try store.ingest(
            statusLineData: try fixture.data(named: "claude_status_line_missing_rate_limits"),
            staleAfterSeconds: 120
        )

        XCTAssertEqual(try store.read().status(now: fixture.now), .stale)
        XCTAssertNil(try store.read().freshMaxUsedPercent(now: fixture.now))
    }

    func testHistoryDeduplicatesSameEventAndNeverDecreasesUsage() throws {
        let fixture = try Fixture()
        let store = fixture.store()
        let first = try ClaudeStatusLineSanitizer().snapshot(
            from: fixture.data(named: "claude_status_line_full"),
            observedAt: fixture.timestamp
        )
        try store.record(first)
        try store.record(first)

        let lower = ClaudeStatusLineSnapshot(
            observedAt: fixture.timestamp,
            model: nil,
            fiveHour: try ClaudeUsageWindowSnapshot(usedPercent: 20, resetsAt: 1_900_010_000),
            sevenDay: nil
        )
        try store.record(lower)
        let samples = try store.readHistory().samples

        XCTAssertEqual(samples.count, 2)
        XCTAssertEqual(samples.first { $0.kind == .fiveHour }?.usedPercent, 42.5)

        fixture.timestamp += 60
        let laterLower = ClaudeStatusLineSnapshot(
            observedAt: fixture.timestamp,
            model: nil,
            fiveHour: try ClaudeUsageWindowSnapshot(usedPercent: 10, resetsAt: 1_900_010_000),
            sevenDay: nil
        )
        try store.record(laterLower)
        XCTAssertEqual(
            try store.readHistory().samples.last { $0.kind == .fiveHour }?.usedPercent,
            42.5
        )
    }

    private final class Fixture {
        let directory: URL
        let cacheURL: URL
        let historyURL: URL
        let initialTimestamp = 1_900_000_000
        var timestamp = 1_900_000_000

        var now: Date { Date(timeIntervalSince1970: TimeInterval(timestamp)) }

        init() throws {
            directory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            cacheURL = directory.appendingPathComponent("claude-usage.json")
            historyURL = directory.appendingPathComponent("claude-usage-history.json")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        deinit {
            try? FileManager.default.removeItem(at: directory)
        }

        func store(
            dataWriter: @escaping (Data, URL, Data.WritingOptions) throws -> Void = {
                try $0.write(to: $1, options: $2)
            }
        ) -> ClaudeUsageCacheStore {
            ClaudeUsageCacheStore(
                fileURL: cacheURL,
                historyFileURL: historyURL,
                dateProvider: { [unowned self] in self.now },
                dataWriter: dataWriter
            )
        }

        func data(named name: String) throws -> Data {
            let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json"))
            return try Data(contentsOf: url)
        }
    }
}
