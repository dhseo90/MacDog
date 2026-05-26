import XCTest
@testable import CodexUsageCore

final class CodexUsageCacheTests: XCTestCase {
    func testDefaultStaleWindowCoversInstalledCacheAgentCadence() {
        XCTAssertGreaterThan(
            CodexUsageCacheStore.defaultStaleAfterSeconds,
            CodexUsageCacheStore.cacheAgentRefreshIntervalSeconds
        )
    }

    func testWritesAndReadsSuccessSnapshot() throws {
        let fileURL = temporaryFileURL()
        let store = CodexUsageCacheStore(fileURL: fileURL, dateProvider: {
            Date(timeIntervalSince1970: 1_779_800_000)
        })
        let report = try makeReport()

        try store.writeSuccess(report: report, staleAfterSeconds: 60)
        let snapshot = try store.read()

        XCTAssertEqual(snapshot.schemaVersion, CodexUsageCacheSnapshot.currentSchemaVersion)
        XCTAssertEqual(snapshot.cachedAt, 1_779_800_000)
        XCTAssertEqual(snapshot.staleAfterSeconds, 60)
        XCTAssertEqual(snapshot.report?.codexLimit?.fiveHour?.usedPercent, 15)
        XCTAssertNil(snapshot.error)
        XCTAssertFalse(snapshot.isStale(now: Date(timeIntervalSince1970: 1_779_800_030)))
        XCTAssertTrue(snapshot.isStale(now: Date(timeIntervalSince1970: 1_779_800_061)))
    }

    func testFailureSnapshotPreservesLastSuccessReport() throws {
        let fileURL = temporaryFileURL()
        var now = 1_779_800_000
        let store = CodexUsageCacheStore(fileURL: fileURL, dateProvider: {
            Date(timeIntervalSince1970: TimeInterval(now))
        })

        try store.writeSuccess(report: makeReport(), staleAfterSeconds: 60)
        now += 10
        try store.writeFailure(message: "network unavailable", staleAfterSeconds: 60)
        let snapshot = try store.read()

        XCTAssertEqual(snapshot.report?.codexLimit?.weekly?.usedPercent, 38)
        XCTAssertEqual(snapshot.error?.message, "network unavailable")
        XCTAssertEqual(snapshot.error?.recordedAt, 1_779_800_010)
        XCTAssertTrue(snapshot.isStale(now: Date(timeIntervalSince1970: 1_779_800_011)))
    }

    private func makeReport() throws -> CodexUsageReport {
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: "rate_limits_response",
            withExtension: "json"
        ))
        let data = try Data(contentsOf: url)
        let response = try JSONDecoder().decode(RateLimitsResponse.self, from: data)
        return CodexUsageReportBuilder(dateProvider: {
            Date(timeIntervalSince1970: 1_779_700_000)
        }).build(from: response)
    }

    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("usage.json")
    }
}
