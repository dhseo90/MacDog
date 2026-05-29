import XCTest
@testable import CodexUsageCore

final class CodexUsageCacheTests: XCTestCase {
    func testDefaultStaleWindowCoversInstalledCacheAgentCadence() {
        XCTAssertGreaterThan(
            CodexUsageCacheStore.defaultStaleAfterSeconds,
            CodexUsageCacheStore.cacheAgentRefreshIntervalSeconds
        )
    }

    func testDefaultAppGroupIdentifierIsStable() {
        XCTAssertEqual(
            CodexUsageCacheStore.defaultAppGroupIdentifier,
            "group.com.dhseo.macdog.MacDog"
        )
    }

    func testDefaultFileURLUsesAppGroupContainerWhenAvailable() {
        let appGroupIdentifier = "group.invalid.\(UUID().uuidString)"
        let url = CodexUsageCacheStore.defaultFileURL(appGroupIdentifier: appGroupIdentifier)

        XCTAssertEqual(url.lastPathComponent, "usage.json")
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            XCTAssertEqual(url, containerURL.appendingPathComponent("usage.json"))
        } else {
            XCTAssertEqual(url, CodexUsageCacheStore.defaultFileURL())
        }
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

    func testSuccessSnapshotUsesStableTopLevelSchemaKeys() throws {
        let fileURL = temporaryFileURL()
        let store = CodexUsageCacheStore(fileURL: fileURL, dateProvider: {
            Date(timeIntervalSince1970: 1_779_800_000)
        })

        try store.writeSuccess(report: makeReport(), staleAfterSeconds: 60)
        let data = try Data(contentsOf: fileURL)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(Set(object.keys), [
            "cachedAt",
            "report",
            "schemaVersion",
            "staleAfterSeconds"
        ])
        XCTAssertEqual(object["schemaVersion"] as? Int, CodexUsageCacheSnapshot.currentSchemaVersion)
        XCTAssertNoSensitiveCacheMaterial(in: object)
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

    func testFailureSnapshotRedactsSensitiveSessionMaterial() throws {
        let fileURL = temporaryFileURL()
        let store = CodexUsageCacheStore(fileURL: fileURL, dateProvider: {
            Date(timeIntervalSince1970: 1_779_800_000)
        })

        try store.writeFailure(
            message: "request failed access_token=abc123 refresh_token:'def456' Authorization: Bearer secret789 cookie=session987",
            staleAfterSeconds: 60
        )

        let snapshot = try store.read()
        let message = try XCTUnwrap(snapshot.error?.message)
        XCTAssertTrue(message.contains("<redacted>"))
        XCTAssertFalse(message.contains("abc123"))
        XCTAssertFalse(message.contains("def456"))
        XCTAssertFalse(message.contains("secret789"))
        XCTAssertFalse(message.contains("session987"))

        let data = try Data(contentsOf: fileURL)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains("abc123"))
        XCTAssertFalse(text.contains("def456"))
        XCTAssertFalse(text.contains("secret789"))
        XCTAssertFalse(text.contains("session987"))
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

    private func XCTAssertNoSensitiveCacheMaterial(
        in value: Any,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let sensitivePattern = "access[_-]?token|refresh[_-]?token|session[_-]?id|authorization|cookie"

        switch value {
        case let dictionary as [String: Any]:
            for (key, nestedValue) in dictionary {
                XCTAssertNil(
                    key.range(of: sensitivePattern, options: [.regularExpression, .caseInsensitive]),
                    file: file,
                    line: line
                )
                XCTAssertNoSensitiveCacheMaterial(in: nestedValue, file: file, line: line)
            }
        case let array as [Any]:
            for nestedValue in array {
                XCTAssertNoSensitiveCacheMaterial(in: nestedValue, file: file, line: line)
            }
        case let string as String:
            XCTAssertNil(
                string.range(of: sensitivePattern, options: [.regularExpression, .caseInsensitive]),
                file: file,
                line: line
            )
        default:
            break
        }
    }
}
