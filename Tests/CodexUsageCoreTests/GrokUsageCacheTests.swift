import Foundation
import XCTest
@testable import CodexUsageCore

final class GrokUsageCacheTests: XCTestCase {
    func testDefaultFilesAreSeparatedFromCodexAndClaudeFiles() {
        XCTAssertEqual(GrokUsageCacheStore.defaultFileURL().lastPathComponent, "grok-usage.json")
        XCTAssertEqual(
            GrokUsageHistoryStore.defaultFileURL(
                adjacentToCacheFileURL: GrokUsageCacheStore.defaultFileURL()
            ).lastPathComponent,
            "grok-usage-history.json"
        )
        XCTAssertNotEqual(GrokUsageCacheStore.defaultFileURL(), CodexUsageCacheStore.defaultFileURL())
        XCTAssertNotEqual(GrokUsageCacheStore.defaultFileURL(), ClaudeUsageCacheStore.defaultFileURL())
    }

    func testSuccessfulWeeklyRecordWritesAtomicCacheAndHistory() throws {
        let fixture = try Fixture()
        var writes: [(String, Data.WritingOptions)] = []
        let store = fixture.store(dataWriter: { data, url, options in
            writes.append((url.lastPathComponent, options))
            try data.write(to: url, options: options)
        })
        let weekly = try XCTUnwrap(GrokUsageWeeklyWindow(usedPercent: 42.5, resetsAt: 1_900_600_000))

        XCTAssertEqual(try store.record(weekly, at: fixture.timestamp), .stored(weekly))
        let cache = try store.read()
        XCTAssertEqual(cache.status(now: fixture.now), .available)
        XCTAssertEqual(cache.source, "unofficial-cli-billing")
        XCTAssertEqual(cache.weekly?.usedPercent, 42.5)
        XCTAssertEqual(cache.weekly?.remainingPercent, 57.5)
        XCTAssertEqual(try store.readHistory().samples.count, 1)
        XCTAssertEqual(Set(writes.map(\.0)), ["grok-usage.json", "grok-usage-history.json"])
        XCTAssertTrue(writes.allSatisfy { $0.1.contains(.atomic) })
        XCTAssertEqual(try fixture.permissions(at: fixture.directory), 0o700)
        XCTAssertEqual(try fixture.permissions(at: fixture.cacheURL), 0o600)
        XCTAssertEqual(try fixture.permissions(at: fixture.historyURL), 0o600)
        XCTAssertEqual(
            try fixture.permissions(at: fixture.directory.appendingPathComponent("grok-usage.lock")),
            0o600
        )
        XCTAssertFalse(try String(contentsOf: fixture.cacheURL).contains("fiveHour"))
        XCTAssertFalse(try String(contentsOf: fixture.cacheURL).contains("prepaidBalance"))
    }

    func testRemainingPercentIsAlwaysOneHundredMinusUsedPercent() {
        XCTAssertEqual(
            GrokUsageWeeklyWindow(usedPercent: 12, remainingPercent: 99, resetsAt: nil)?.remainingPercent,
            88
        )
        XCTAssertNil(GrokUsageWeeklyWindow(usedPercent: 120, resetsAt: nil))
        XCTAssertNil(GrokUsageWeeklyWindow(usedPercent: .nan, resetsAt: nil))
    }

    func testWeeklyMissingSnapshotIsWaitingAndDoesNotSynthesizeFiveHour() throws {
        let cache = GrokUsageCacheSnapshot(
            fetchedAt: 1_900_000_000,
            lastUsageObservedAt: nil,
            staleAfterSeconds: 180,
            weekly: nil,
            issue: GrokUsageCacheIssue(code: "weekly-window-missing", recordedAt: 1_900_000_000)
        )
        XCTAssertEqual(cache.status(), .error)
        XCTAssertNil(cache.freshWeekly())
        XCTAssertNil(cache.weekly)
    }

    func testFailurePreservesLastWeeklyAndSanitizesIssueCode() throws {
        let fixture = try Fixture()
        let store = fixture.store()
        let weekly = try XCTUnwrap(GrokUsageWeeklyWindow(usedPercent: 33, resetsAt: 1_900_600_000))
        _ = try store.record(weekly, at: fixture.timestamp)

        fixture.timestamp += 60
        XCTAssertEqual(
            try store.recordFailure(code: "session-secret-should-not-persist", at: fixture.timestamp),
            .failed(code: "unknown_error")
        )
        let cache = try store.read()
        XCTAssertEqual(cache.status(now: fixture.now), .error)
        XCTAssertEqual(cache.issue?.code, "unknown_error")
        XCTAssertEqual(cache.weekly?.usedPercent, 33)
        XCTAssertFalse(try String(contentsOf: fixture.cacheURL).contains("session-secret"))
        XCTAssertEqual(try store.readHistory().samples.count, 1)
    }

    func testStaleUsesLastUsageObservation() throws {
        let fixture = try Fixture()
        let store = fixture.store()
        let weekly = try XCTUnwrap(GrokUsageWeeklyWindow(usedPercent: 10, resetsAt: 1_900_600_000))
        _ = try store.record(weekly, at: fixture.timestamp, staleAfterSeconds: 120)
        fixture.timestamp += 121
        XCTAssertEqual(try store.read().status(now: fixture.now), .stale)
        XCTAssertNil(try store.read().freshWeekly(now: fixture.now))
    }

    func testHistoryDoesNotDecreaseUsedPercentInSameResetWindow() throws {
        let fixture = try Fixture()
        let store = fixture.store()
        let first = try XCTUnwrap(GrokUsageWeeklyWindow(usedPercent: 40, resetsAt: 1_900_600_000))
        let lower = try XCTUnwrap(GrokUsageWeeklyWindow(usedPercent: 20, resetsAt: 1_900_600_000))
        _ = try store.record(first, at: fixture.timestamp)
        fixture.timestamp += 60
        _ = try store.record(lower, at: fixture.timestamp)

        let samples = try store.readHistory().samples
        XCTAssertEqual(samples.map(\.usedPercent), [40, 40])
        XCTAssertEqual(samples.map(\.remainingPercent), [60, 60])
    }

    func testPaceWaitsWhenSamplesAreInsufficientAndProjectsFromSameResetWindow() throws {
        let weekly = try XCTUnwrap(GrokUsageWeeklyWindow(usedPercent: 30, resetsAt: 1_900_604_800))
        let waiting = GrokUsagePaceProjectionBuilder().projection(
            weekly: weekly,
            history: .empty,
            now: 1_900_003_600
        )
        XCTAssertEqual(waiting.state, .waitingForSamples)

        let history = GrokUsageHistory(samples: [
            try XCTUnwrap(GrokUsageHistorySample(
                recordedAt: 1_900_000_000,
                usedPercent: 20,
                remainingPercent: 80,
                resetsAt: 1_900_604_800
            )),
            try XCTUnwrap(GrokUsageHistorySample(
                recordedAt: 1_900_003_600,
                usedPercent: 30,
                remainingPercent: 70,
                resetsAt: 1_900_604_800
            ))
        ])
        let projected = GrokUsagePaceProjectionBuilder().projection(
            weekly: weekly,
            history: history,
            now: 1_900_003_600
        )
        XCTAssertEqual(projected.state, .projected)
        XCTAssertEqual(try XCTUnwrap(projected.usedPercentPerHour), 10, accuracy: 0.0001)
    }

    func testFailedHistoryWritePreservesExistingCacheAndHistory() throws {
        let fixture = try Fixture()
        let store = fixture.store()
        let weekly = try XCTUnwrap(GrokUsageWeeklyWindow(usedPercent: 40, resetsAt: 1_900_600_000))
        _ = try store.record(weekly, at: fixture.timestamp)
        let cacheBefore = try Data(contentsOf: fixture.cacheURL)
        let historyBefore = try Data(contentsOf: fixture.historyURL)
        fixture.timestamp += 60
        let failingStore = fixture.store(dataWriter: { _, _, _ in
            throw CocoaError(.fileWriteUnknown)
        })

        XCTAssertThrowsError(try failingStore.record(weekly, at: fixture.timestamp))
        XCTAssertEqual(try Data(contentsOf: fixture.cacheURL), cacheBefore)
        XCTAssertEqual(try Data(contentsOf: fixture.historyURL), historyBefore)
    }

    private final class Fixture {
        let directory: URL
        let cacheURL: URL
        let historyURL: URL
        var timestamp = 1_900_000_000

        var now: Date { Date(timeIntervalSince1970: TimeInterval(timestamp)) }

        init() throws {
            directory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            cacheURL = directory.appendingPathComponent("grok-usage.json")
            historyURL = directory.appendingPathComponent("grok-usage-history.json")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        deinit {
            try? FileManager.default.removeItem(at: directory)
        }

        func store(
            dataWriter: @escaping (Data, URL, Data.WritingOptions) throws -> Void = {
                try $0.write(to: $1, options: $2)
            }
        ) -> GrokUsageCacheStore {
            GrokUsageCacheStore(
                fileURL: cacheURL,
                historyFileURL: historyURL,
                dateProvider: { [unowned self] in self.now },
                dataWriter: dataWriter
            )
        }

        func permissions(at url: URL) throws -> Int {
            let values = try FileManager.default.attributesOfItem(atPath: url.path)
            return Int(truncating: values[.posixPermissions] as? NSNumber ?? 0)
        }
    }
}
