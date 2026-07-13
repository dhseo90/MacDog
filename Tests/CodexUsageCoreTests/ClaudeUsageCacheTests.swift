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
        XCTAssertEqual(try fixture.permissions(at: fixture.directory), 0o700)
        XCTAssertEqual(try fixture.permissions(at: fixture.cacheURL), 0o600)
        XCTAssertEqual(try fixture.permissions(at: fixture.historyURL), 0o600)
        XCTAssertEqual(
            try fixture.permissions(at: fixture.directory.appendingPathComponent("claude-usage.lock")),
            0o600
        )
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

    func testExpiredWindowIsExcludedWhileOtherFreshWindowKeepsPartialState() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let usage = ClaudeStatusLineSnapshot(
            observedAt: 1_899_999_900,
            fiveHour: try ClaudeUsageWindowSnapshot(usedPercent: 99, resetsAt: 1_899_999_999),
            sevenDay: try ClaudeUsageWindowSnapshot(usedPercent: 20, resetsAt: 1_900_100_000)
        )
        let cache = ClaudeUsageCacheSnapshot(
            lastEventAt: usage.observedAt,
            lastUsageObservedAt: usage.observedAt,
            staleAfterSeconds: 900,
            usage: usage,
            issue: nil
        )

        XCTAssertEqual(cache.status(now: now), .partial)
        XCTAssertNil(cache.freshWindow(.fiveHour, now: now))
        XCTAssertEqual(cache.freshWindow(.sevenDay, now: now)?.usedPercent, 20)
        XCTAssertEqual(cache.freshMaxUsedPercent(now: now), 20)
    }

    func testFailureCodeAllowlistCannotPersistArbitrarySensitiveText() throws {
        let fixture = try Fixture()
        let store = fixture.store()

        try store.recordFailure(
            code: "session-secret-should-not-persist",
            at: fixture.timestamp
        )

        XCTAssertEqual(try store.read().issue?.code, "unknown_error")
        XCTAssertFalse(try String(contentsOf: fixture.cacheURL).contains("session-secret"))
    }

    func testOversizedInputIsRejectedWithSanitizedIssue() throws {
        let fixture = try Fixture()
        let store = fixture.store()
        let oversized = Data(
            repeating: 0x41,
            count: ClaudeUsageCacheStore.maximumStatusLineBytes + 1
        )

        XCTAssertEqual(
            try store.ingest(statusLineData: oversized),
            .failed(code: "status_line_too_large")
        )
        XCTAssertEqual(try store.read().issue?.code, "status_line_too_large")
        XCTAssertLessThan(try Data(contentsOf: fixture.cacheURL).count, 4_096)
    }

    func testFailedHistoryWritePreservesExistingCacheAndHistory() throws {
        let fixture = try Fixture()
        let store = fixture.store()
        _ = try store.ingest(statusLineData: try fixture.data(named: "claude_status_line_full"))
        let cacheBefore = try Data(contentsOf: fixture.cacheURL)
        let historyBefore = try Data(contentsOf: fixture.historyURL)
        fixture.timestamp += 60
        let failingStore = fixture.store(dataWriter: { _, _, _ in
            throw CocoaError(.fileWriteUnknown)
        })

        XCTAssertThrowsError(
            try failingStore.ingest(statusLineData: fixture.data(named: "claude_status_line_full"))
        )
        XCTAssertEqual(try Data(contentsOf: fixture.cacheURL), cacheBefore)
        XCTAssertEqual(try Data(contentsOf: fixture.historyURL), historyBefore)
    }

    func testReadStateReturnsCacheAndHistoryUnderOneStoreLock() throws {
        let fixture = try Fixture()
        let store = fixture.store()
        _ = try store.ingest(statusLineData: try fixture.data(named: "claude_status_line_full"))

        let storedState = try store.readState()

        XCTAssertEqual(storedState.cacheSnapshot?.lastUsageObservedAt, fixture.timestamp)
        XCTAssertEqual(storedState.history.samples.count, 2)
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
            fiveHour: try ClaudeUsageWindowSnapshot(usedPercent: 10, resetsAt: 1_900_010_000),
            sevenDay: nil
        )
        try store.record(laterLower)
        XCTAssertEqual(
            try store.readHistory().samples.last { $0.kind == .fiveHour }?.usedPercent,
            42.5
        )
    }

    func testPaceProjectionUsesConsecutiveSamplesWithinSameWindow() throws {
        let resetsAt = 1_900_010_000
        let history = ClaudeUsageHistory(samples: [
            try XCTUnwrap(ClaudeUsageHistorySample(
                kind: .fiveHour,
                recordedAt: 1_900_000_000,
                usedPercent: 20,
                resetsAt: resetsAt
            )),
            try XCTUnwrap(ClaudeUsageHistorySample(
                kind: .fiveHour,
                recordedAt: 1_900_003_600,
                usedPercent: 30,
                resetsAt: resetsAt
            ))
        ])
        let snapshot = ClaudeStatusLineSnapshot(
            observedAt: 1_900_003_600,
            fiveHour: try ClaudeUsageWindowSnapshot(usedPercent: 30, resetsAt: resetsAt),
            sevenDay: nil
        )

        let projection = ClaudeUsagePaceProjectionBuilder().projection(
            kind: .fiveHour,
            snapshot: snapshot,
            history: history
        )

        XCTAssertEqual(projection.state, .projected)
        XCTAssertEqual(try XCTUnwrap(projection.usedPercentPerHour), 10, accuracy: 0.0001)
        XCTAssertEqual(
            try XCTUnwrap(projection.projectedFinalUsedPercent),
            47.77777777777778,
            accuracy: 0.0001
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

        func permissions(at url: URL) throws -> Int {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return try XCTUnwrap((attributes[.posixPermissions] as? NSNumber)?.intValue)
        }
    }
}
