import XCTest
@testable import CodexUsageCore

final class UsageResetWindowHistoryTests: XCTestCase {
    func testRecordKeyUsesLimitWindowDurationAndResetsAt() {
        let record = Self.record(
            limitId: "codex",
            windowDurationMins: 10_080,
            resetsAt: 1_800_345_600
        )

        XCTAssertEqual(
            record.key,
            CodexUsageResetWindowHistoryKey(
                limitId: "codex",
                windowDurationMins: 10_080,
                resetsAt: 1_800_345_600
            )
        )
        XCTAssertEqual(record.resetStartAt, 1_800_345_600 - 10_080 * 60)
    }

    func testResetWindowHistoryJSONUsesMinimalStableKeys() throws {
        let history = CodexUsageResetWindowHistory(records: [
            Self.record(
                generatedAt: 1_800_000_000,
                limitId: "codex",
                windowDurationMins: 10_080,
                resetsAt: 1_800_345_600,
                sampleCount: 2,
                source: .liveCache
            )
        ])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(history)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let records = try XCTUnwrap(object["records"] as? [[String: Any]])
        let encodedRecord = try XCTUnwrap(records.first)
        let samples = try XCTUnwrap(encodedRecord["dailyEndSamples"] as? [[String: Any]])

        XCTAssertEqual(Set(object.keys), ["records", "schemaVersion"])
        XCTAssertEqual(object["schemaVersion"] as? Int, CodexUsageResetWindowHistory.currentSchemaVersion)
        XCTAssertEqual(
            Set(encodedRecord.keys),
            [
                "dailyEndSamples",
                "finalRemainingPercent",
                "finalUsedPercent",
                "generatedAt",
                "limitId",
                "resetsAt",
                "resetStartAt",
                "sampleCount",
                "schemaVersion",
                "source",
                "windowDurationMins"
            ]
        )
        XCTAssertEqual(encodedRecord["source"] as? String, "live-cache")
        XCTAssertEqual(Set(samples[0].keys), ["dayIndex", "recordedAt", "remainingPercent", "usedPercent"])
        XCTAssertNoSensitiveHistoryMaterial(in: object)
    }

    func testExistingWeeklyHistoryV1SchemaStaysStable() throws {
        let history = CodexUsageWeeklyHistory(samples: [
            CodexUsageWeeklyHistorySample(
                recordedAt: 1_800_000_000,
                usedPercent: 38,
                remainingPercent: 62,
                resetsAt: 1_800_345_600,
                windowDurationMins: 10_080
            )
        ])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(history)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let samples = try XCTUnwrap(object["samples"] as? [[String: Any]])
        let encodedSample = try XCTUnwrap(samples.first)

        XCTAssertEqual(Set(object.keys), ["samples", "schemaVersion"])
        XCTAssertEqual(object["schemaVersion"] as? Int, CodexUsageWeeklyHistory.currentSchemaVersion)
        XCTAssertEqual(
            Set(encodedSample.keys),
            ["recordedAt", "remainingPercent", "resetsAt", "usedPercent", "windowDurationMins"]
        )
    }

    func testStoreUsesSeparateDefaultFileNextToUsageCache() {
        let cacheURL = URL(fileURLWithPath: "/tmp/MacDog/usage.json")
        let historyURL = CodexUsageResetWindowHistoryStore.defaultFileURL(adjacentToCacheFileURL: cacheURL)

        XCTAssertEqual(historyURL.lastPathComponent, "usage-reset-window-history.json")
        XCTAssertEqual(historyURL.deletingLastPathComponent(), cacheURL.deletingLastPathComponent())
        XCTAssertNotEqual(historyURL.lastPathComponent, CodexUsageWeeklyHistoryStore.fileName)
    }

    func testStoreUpsertsByResetWindowKeyAndSkipsIdenticalRecord() throws {
        let fileURL = temporaryResetHistoryFileURL()
        let store = CodexUsageResetWindowHistoryStore(fileURL: fileURL)
        let first = Self.record(
            generatedAt: 1_800_000_000,
            limitId: "codex",
            windowDurationMins: 10_080,
            resetsAt: 1_800_345_600,
            sampleCount: 1
        )
        let updated = Self.record(
            generatedAt: 1_800_000_060,
            limitId: "codex",
            windowDurationMins: 10_080,
            resetsAt: 1_800_345_600,
            sampleCount: 2
        )

        XCTAssertTrue(try store.append(first))
        XCTAssertFalse(try store.append(first))
        XCTAssertTrue(try store.append(updated))

        let history = try store.read()
        XCTAssertEqual(history.records.count, 1)
        XCTAssertEqual(history.records.first?.key, first.key)
        XCTAssertEqual(history.records.first?.generatedAt, 1_800_000_060)
        XCTAssertEqual(history.records.first?.sampleCount, 2)
    }

    func testStoreRetainsCurrentWindowAndTwelveCompletedWindowsPerLimitWindow() throws {
        let fileURL = temporaryResetHistoryFileURL()
        let store = CodexUsageResetWindowHistoryStore(fileURL: fileURL)
        let durationSeconds = 10_080 * 60
        let firstReset = 1_800_000_000

        for index in 0..<14 {
            _ = try store.append(Self.record(
                generatedAt: firstReset + index,
                limitId: "codex",
                windowDurationMins: 10_080,
                resetsAt: firstReset + index * durationSeconds
            ))
        }

        let history = try store.read()
        XCTAssertEqual(history.records.count, 13)
        XCTAssertEqual(history.records.first?.resetsAt, firstReset + durationSeconds)
        XCTAssertEqual(history.records.last?.resetsAt, firstReset + 13 * durationSeconds)
    }

    func testStoreMigratesLegacySchemaVersionOnRead() throws {
        let fileURL = temporaryResetHistoryFileURL()
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try legacyHistoryJSON(schemaVersion: 0, recordSchemaVersion: 0)
            .write(to: fileURL, atomically: true, encoding: .utf8)

        let history = try CodexUsageResetWindowHistoryStore(fileURL: fileURL).read()

        XCTAssertEqual(history.schemaVersion, CodexUsageResetWindowHistory.currentSchemaVersion)
        XCTAssertEqual(history.records.first?.schemaVersion, CodexUsageResetWindowHistoryRecord.currentSchemaVersion)
        XCTAssertEqual(history.records.first?.key.limitId, "codex")
    }

    func testStoreWritesNoSensitiveMaterialOrRawResponseKeys() throws {
        let fileURL = temporaryResetHistoryFileURL()
        let store = CodexUsageResetWindowHistoryStore(fileURL: fileURL)

        XCTAssertTrue(try store.append(Self.record(
            limitId: "codex",
            windowDurationMins: 10_080,
            resetsAt: 1_800_345_600
        )))

        let text = try String(contentsOf: fileURL)
        XCTAssertFalse(text.contains("access_token"))
        XCTAssertFalse(text.contains("refresh_token"))
        XCTAssertFalse(text.contains("authorization"))
        XCTAssertFalse(text.contains("cookie"))
        XCTAssertFalse(text.contains("rawResponse"))
        XCTAssertFalse(text.contains("sessionMaterial"))
    }

    private static func record(
        generatedAt: Int = 1_800_000_000,
        limitId: String,
        windowDurationMins: Int,
        resetsAt: Int,
        sampleCount: Int = 1,
        source: CodexUsageResetWindowHistorySource = .liveCache
    ) -> CodexUsageResetWindowHistoryRecord {
        CodexUsageResetWindowHistoryRecord(
            generatedAt: generatedAt,
            limitId: limitId,
            windowDurationMins: windowDurationMins,
            resetsAt: resetsAt,
            dailyEndSamples: [
                CodexUsageResetWindowDailySample(
                    dayIndex: 1,
                    recordedAt: generatedAt,
                    usedPercent: 28,
                    remainingPercent: 72
                )
            ],
            finalUsedPercent: 28,
            finalRemainingPercent: 72,
            sampleCount: sampleCount,
            source: source
        )
    }

    private func temporaryResetHistoryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("usage-reset-window-history.json")
    }

    private func legacyHistoryJSON(schemaVersion: Int, recordSchemaVersion: Int) -> String {
        """
        {
          "schemaVersion": \(schemaVersion),
          "records": [
            {
              "schemaVersion": \(recordSchemaVersion),
              "generatedAt": 1800000000,
              "limitId": "codex",
              "windowDurationMins": 10080,
              "resetStartAt": 1799740800,
              "resetsAt": 1800345600,
              "dailyEndSamples": [
                {
                  "dayIndex": 1,
                  "recordedAt": 1800000000,
                  "usedPercent": 28,
                  "remainingPercent": 72
                }
              ],
              "finalUsedPercent": 28,
              "finalRemainingPercent": 72,
              "sampleCount": 1,
              "source": "live-cache"
            }
          ]
        }
        """
    }

    private func XCTAssertNoSensitiveHistoryMaterial(
        in value: Any,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let sensitivePattern = "access[_-]?token|refresh[_-]?token|session|authorization|cookie|raw"

        switch value {
        case let dictionary as [String: Any]:
            for (key, nestedValue) in dictionary {
                XCTAssertNil(
                    key.range(of: sensitivePattern, options: [.regularExpression, .caseInsensitive]),
                    file: file,
                    line: line
                )
                XCTAssertNoSensitiveHistoryMaterial(in: nestedValue, file: file, line: line)
            }
        case let array as [Any]:
            for nestedValue in array {
                XCTAssertNoSensitiveHistoryMaterial(in: nestedValue, file: file, line: line)
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
