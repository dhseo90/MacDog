import Foundation
import XCTest
@testable import CodexUsageCore

final class CodexUsageFiveHourHistoryTests: XCTestCase {
    func testHistoryJSONUsesMinimalPrivacySafeSchema() throws {
        let sample = try XCTUnwrap(Self.sample())
        let history = CodexUsageFiveHourHistory(samples: [sample])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(history)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let samples = try XCTUnwrap(object["samples"] as? [[String: Any]])
        let encodedSample = try XCTUnwrap(samples.first)

        XCTAssertEqual(Set(object.keys), ["samples", "schemaVersion"])
        XCTAssertEqual(object["schemaVersion"] as? Int, CodexUsageFiveHourHistory.currentSchemaVersion)
        XCTAssertEqual(
            Set(encodedSample.keys),
            ["recordedAt", "resetsAt", "schemaVersion", "usedPercent", "windowDurationMins"]
        )
        XCTAssertEqual(encodedSample["windowDurationMins"] as? Int, 300)
        XCTAssertNoSensitiveMaterial(in: data)
    }

    func testSampleAcceptsOnlyFiveHourWindow() throws {
        XCTAssertNotNil(Self.sample(windowDurationMins: 300))
        XCTAssertNil(Self.sample(windowDurationMins: 10_080))

        let invalidJSON = """
        {
          "schemaVersion": 1,
          "samples": [{
            "schemaVersion": 1,
            "recordedAt": 1800000000,
            "windowDurationMins": 10080,
            "usedPercent": 24,
            "resetsAt": 1800018000,
            "planEpochID": "before-transition"
          }]
        }
        """

        XCTAssertThrowsError(
            try JSONDecoder().decode(
                CodexUsageFiveHourHistory.self,
                from: Data(invalidJSON.utf8)
            )
        )
    }

    func testStoreUsesSeparateDefaultFileNextToUsageCache() {
        let cacheURL = URL(fileURLWithPath: "/tmp/MacDog/usage.json")
        let historyURL = CodexUsageFiveHourHistoryStore.defaultFileURL(
            adjacentToCacheFileURL: cacheURL
        )

        XCTAssertEqual(historyURL.lastPathComponent, "usage-five-hour-history.json")
        XCTAssertEqual(historyURL.deletingLastPathComponent(), cacheURL.deletingLastPathComponent())
        XCTAssertNotEqual(historyURL.lastPathComponent, CodexUsageWeeklyHistoryStore.fileName)
        XCTAssertNotEqual(historyURL.lastPathComponent, CodexUsageResetWindowHistoryStore.fileName)
    }

    func testStoreWritesWithAtomicOption() throws {
        let fileURL = temporaryHistoryFileURL()
        var capturedOptions: Data.WritingOptions = []
        let store = CodexUsageFiveHourHistoryStore(
            fileURL: fileURL,
            dataWriter: { data, destination, options in
                capturedOptions = options
                try data.write(to: destination, options: options)
            }
        )

        XCTAssertTrue(try store.append(try XCTUnwrap(Self.sample())))
        XCTAssertTrue(capturedOptions.contains(.atomic))
        XCTAssertEqual(try store.read().samples.count, 1)
    }

    func testStoreRetainsOnlySamplesWithinThirteenWeeks() throws {
        let fileURL = temporaryHistoryFileURL()
        let store = CodexUsageFiveHourHistoryStore(fileURL: fileURL)
        let newestRecordedAt = 1_810_000_000
        let cutoff = newestRecordedAt - CodexUsageFiveHourHistoryStore.defaultRetentionSeconds

        XCTAssertTrue(try store.append(try XCTUnwrap(Self.sample(
            recordedAt: cutoff - 1,
            resetsAt: cutoff + 18_000
        ))))
        XCTAssertTrue(try store.append(try XCTUnwrap(Self.sample(
            recordedAt: cutoff,
            resetsAt: cutoff + 36_000
        ))))
        XCTAssertTrue(try store.append(try XCTUnwrap(Self.sample(
            recordedAt: newestRecordedAt,
            resetsAt: newestRecordedAt + 18_000
        ))))

        let history = try store.read()
        XCTAssertEqual(history.samples.map(\.recordedAt), [cutoff, newestRecordedAt])
    }

    func testStoreRejectsOutOfOrderSampleOlderThanRetentionWindow() throws {
        let fileURL = temporaryHistoryFileURL()
        let store = CodexUsageFiveHourHistoryStore(fileURL: fileURL)
        let newestRecordedAt = 1_810_000_000
        let oldRecordedAt = newestRecordedAt - CodexUsageFiveHourHistoryStore.defaultRetentionSeconds - 1

        XCTAssertTrue(try store.append(try XCTUnwrap(Self.sample(
            recordedAt: newestRecordedAt,
            resetsAt: newestRecordedAt + 18_000
        ))))
        XCTAssertFalse(try store.append(try XCTUnwrap(Self.sample(
            recordedAt: oldRecordedAt,
            resetsAt: oldRecordedAt + 18_000
        ))))

        XCTAssertEqual(try store.read().samples.map(\.recordedAt), [newestRecordedAt])
    }

    func testStoreSkipsDenseSampleInsideSameLogicalWindow() throws {
        let fileURL = temporaryHistoryFileURL()
        let store = CodexUsageFiveHourHistoryStore(fileURL: fileURL)
        let first = try XCTUnwrap(Self.sample(usedPercent: 24))
        let dense = try XCTUnwrap(Self.sample(
            recordedAt: first.recordedAt + 120,
            usedPercent: 24.1,
            resetsAt: first.resetsAt + 60
        ))

        XCTAssertTrue(try store.append(first))
        XCTAssertFalse(try store.append(dense))
        XCTAssertEqual(try store.read().samples, [first])
    }

    func testStoreKeepsSamplesAcrossResetBoundaries() throws {
        let fileURL = temporaryHistoryFileURL()
        let store = CodexUsageFiveHourHistoryStore(fileURL: fileURL)
        let first = try XCTUnwrap(Self.sample())
        let nextReset = try XCTUnwrap(Self.sample(
            recordedAt: first.recordedAt + 120,
            resetsAt: first.resetsAt + 18_000
        ))

        XCTAssertTrue(try store.append(first))
        XCTAssertTrue(try store.append(nextReset))
        XCTAssertEqual(try store.read().samples.count, 2)
    }

    func testStoreDecodesLegacyEpochButNewEncodingOmitsIt() throws {
        let fileURL = temporaryHistoryFileURL()
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let legacyJSON = """
        {
          "schemaVersion": 0,
          "samples": [{
            "recordedAt": 1800000000,
            "windowDurationMins": 300,
            "usedPercent": 24,
            "resetsAt": 1800018000,
            "planEpochID": "before-transition"
          }]
        }
        """
        try Data(legacyJSON.utf8).write(to: fileURL, options: [.atomic])

        let history = try CodexUsageFiveHourHistoryStore(fileURL: fileURL).read()

        XCTAssertEqual(history.schemaVersion, CodexUsageFiveHourHistory.currentSchemaVersion)
        XCTAssertEqual(history.samples.first?.schemaVersion, CodexUsageFiveHourHistorySample.currentSchemaVersion)
        let encoded = try JSONEncoder().encode(history)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("planEpochID"))
    }

    func testPersistedHistoryContainsNoSensitiveFieldNames() throws {
        let fileURL = temporaryHistoryFileURL()
        let store = CodexUsageFiveHourHistoryStore(fileURL: fileURL)

        XCTAssertTrue(try store.append(try XCTUnwrap(Self.sample())))

        XCTAssertNoSensitiveMaterial(in: try Data(contentsOf: fileURL))
    }

    private static func sample(
        recordedAt: Int = 1_800_000_000,
        windowDurationMins: Int = 300,
        usedPercent: Double = 24,
        resetsAt: Int = 1_800_018_000
    ) -> CodexUsageFiveHourHistorySample? {
        CodexUsageFiveHourHistorySample(
            recordedAt: recordedAt,
            windowDurationMins: windowDurationMins,
            usedPercent: usedPercent,
            resetsAt: resetsAt
        )
    }

    private func temporaryHistoryFileURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return directory.appendingPathComponent(CodexUsageFiveHourHistoryStore.fileName)
    }

    private func XCTAssertNoSensitiveMaterial(
        in data: Data,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let text = String(decoding: data, as: UTF8.self).lowercased()
        for forbiddenKey in [
            "access_token",
            "refreshtoken",
            "refresh_token",
            "authorization",
            "cookie",
            "sessionmaterial",
            "rawresponse",
            "rawlog"
        ] {
            XCTAssertFalse(text.contains(forbiddenKey), "Found \(forbiddenKey)", file: file, line: line)
        }
    }
}
