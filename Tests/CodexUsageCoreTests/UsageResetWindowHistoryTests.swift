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

    func testStoreMergesRollingResetTimestampSamplesIntoOneLogicalWeeklyWindow() throws {
        let fileURL = temporaryResetHistoryFileURL()
        let store = CodexUsageResetWindowHistoryStore(fileURL: fileURL)
        let firstRecordedAt = 1_800_000_000
        let durationSeconds = 10_080 * 60
        let firstSample = Self.weeklySample(
            recordedAt: firstRecordedAt,
            remainingPercent: 100,
            resetsAt: firstRecordedAt + durationSeconds
        )
        let laterSample = Self.weeklySample(
            recordedAt: firstRecordedAt + 9 * 60,
            remainingPercent: 99,
            resetsAt: firstRecordedAt + durationSeconds + 9 * 60
        )

        XCTAssertTrue(try store.append(sample: firstSample, generatedAt: firstSample.recordedAt))
        XCTAssertTrue(try store.append(sample: laterSample, generatedAt: laterSample.recordedAt))

        let history = try store.read()
        let record = try XCTUnwrap(history.records.first)
        XCTAssertEqual(history.records.count, 1)
        XCTAssertEqual(record.key.resetsAt, firstSample.resetsAt)
        XCTAssertEqual(record.finalRemainingPercent, 99)
        XCTAssertEqual(record.sampleCount, 2)
        XCTAssertEqual(record.dailyEndSamples.count, 1)
        XCTAssertEqual(record.dailyEndSamples.first?.remainingPercent, 99)
    }

    func testStoreKeepsSameDayObservedResetWindowsApart() throws {
        let fileURL = temporaryResetHistoryFileURL()
        let store = CodexUsageResetWindowHistoryStore(fileURL: fileURL)
        let firstResetStart = 1_800_000_000
        let durationSeconds = 10_080 * 60
        let nextResetStart = firstResetStart + 11 * 60 * 60
        let firstSample = Self.weeklySample(
            recordedAt: firstResetStart + 10 * 60 * 60,
            remainingPercent: 33,
            resetsAt: firstResetStart + durationSeconds
        )
        let nextSample = Self.weeklySample(
            recordedAt: nextResetStart + 60,
            remainingPercent: 100,
            resetsAt: nextResetStart + durationSeconds
        )

        XCTAssertTrue(try store.append(sample: firstSample, generatedAt: firstSample.recordedAt))
        XCTAssertTrue(try store.append(sample: nextSample, generatedAt: nextSample.recordedAt))

        let history = try store.read()
        XCTAssertEqual(history.records.map(\.resetsAt), [firstSample.resetsAt, nextSample.resetsAt])
        XCTAssertEqual(history.records.map(\.finalRemainingPercent), [33, 100])
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

    func testBackfillSummaryAppendsOnlyGeneratedHistoryRecords() throws {
        let fileURL = temporaryResetHistoryFileURL()
        let store = CodexUsageResetWindowHistoryStore(fileURL: fileURL)
        let summary = CodexUsageResetWindowBackfillSummary(
            generatedAt: 1_800_604_740,
            limitId: "codex",
            windowDurationMins: 10_080,
            resetsAt: 1_800_604_800,
            dailyEndSamples: [
                CodexUsageResetWindowDailySample(
                    dayIndex: 7,
                    recordedAt: 1_800_604_800,
                    usedPercent: 74,
                    remainingPercent: 26
                )
            ],
            finalUsedPercent: 74,
            finalRemainingPercent: 26,
            sampleCount: 7
        )

        XCTAssertEqual(try store.appendBackfillSummaries([summary]), 1)

        let history = try store.read()
        let record = try XCTUnwrap(history.records.first)
        XCTAssertEqual(record.source, .backfill)
        XCTAssertEqual(record.finalUsedPercent, 74)
        XCTAssertEqual(record.dailyEndSamples.first?.dayIndex, 7)
    }

    func testBackfillSummariesUseCompletedWeeklyHistoryAndExcludeCurrentFutureWindow() throws {
        let pastReset = 1_800_604_800
        let currentReset = pastReset + 604_800
        let pastStart = pastReset - 604_800
        let weeklyHistory = CodexUsageWeeklyHistory(samples: [
            Self.weeklySample(recordedAt: pastStart + 60 * 60, remainingPercent: 92, resetsAt: pastReset),
            Self.weeklySample(recordedAt: pastStart + 86_400 + 90, remainingPercent: 81, resetsAt: pastReset),
            Self.weeklySample(recordedAt: pastStart + 2 * 86_400 + 120, remainingPercent: 63, resetsAt: pastReset + 1),
            Self.weeklySample(recordedAt: pastReset - 60, remainingPercent: 26, resetsAt: pastReset),
            Self.weeklySample(recordedAt: pastReset + 60, remainingPercent: 100, resetsAt: currentReset),
            Self.weeklySample(recordedAt: pastReset + 120, remainingPercent: 100, resetsAt: currentReset + 1)
        ])

        let summaries = CodexUsageResetWindowBackfillBuilder().summaries(
            from: weeklyHistory,
            completedAtOrBefore: pastReset + 120,
            excludingCurrentResetsAt: currentReset
        )

        let summary = try XCTUnwrap(summaries.first)
        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summary.resetsAt, pastReset)
        XCTAssertEqual(summary.finalUsedPercent, 74)
        XCTAssertEqual(summary.finalRemainingPercent, 26)
        XCTAssertEqual(summary.sampleCount, 4)
        XCTAssertEqual(summary.dailyEndSamples.map(\.dayIndex), [1, 2, 3, 7])
    }

    func testBackfillSummariesIncludeInterruptedFutureResetWindowsBeforeCurrentWindow() throws {
        let firstResetStart = 1_800_000_000
        let durationSeconds = 10_080 * 60
        let firstReset = firstResetStart + durationSeconds
        let secondResetStart = firstResetStart + 3 * 86_400 + 16 * 60 * 60
        let secondReset = secondResetStart + durationSeconds
        let currentResetStart = secondResetStart + 11 * 60 * 60
        let currentReset = currentResetStart + durationSeconds
        let weeklyHistory = CodexUsageWeeklyHistory(samples: [
            Self.weeklySample(recordedAt: firstResetStart + 6 * 60 * 60, remainingPercent: 97, resetsAt: firstReset),
            Self.weeklySample(
                recordedAt: firstResetStart + 86_400 + 8 * 60 * 60,
                remainingPercent: 85,
                resetsAt: firstReset + 73 * 60
            ),
            Self.weeklySample(recordedAt: secondResetStart - 30 * 60, remainingPercent: 33, resetsAt: firstReset),
            Self.weeklySample(recordedAt: secondResetStart + 60, remainingPercent: 100, resetsAt: secondReset),
            Self.weeklySample(recordedAt: currentResetStart - 10 * 60, remainingPercent: 97, resetsAt: secondReset),
            Self.weeklySample(recordedAt: currentResetStart + 60, remainingPercent: 100, resetsAt: currentReset)
        ])

        let summaries = CodexUsageResetWindowBackfillBuilder().summaries(
            from: weeklyHistory,
            completedAtOrBefore: currentResetStart + 2 * 60,
            excludingCurrentResetsAt: currentReset
        )

        XCTAssertEqual(summaries.map(\.resetsAt), [firstReset, secondReset])
        XCTAssertEqual(summaries.map(\.finalRemainingPercent), [33, 97])
        XCTAssertEqual(summaries.map(\.sampleCount), [3, 2])
    }

    func testBackfillSummaryJSONDoesNotStoreRawLogOrSessionMaterial() throws {
        let summary = CodexUsageResetWindowBackfillSummary(
            generatedAt: 1_800_604_740,
            limitId: "codex",
            windowDurationMins: 10_080,
            resetsAt: 1_800_604_800,
            dailyEndSamples: [
                CodexUsageResetWindowDailySample(
                    dayIndex: 7,
                    recordedAt: 1_800_604_800,
                    usedPercent: 74,
                    remainingPercent: 26
                )
            ],
            finalUsedPercent: 74,
            finalRemainingPercent: 26,
            sampleCount: 7
        )
        let record = CodexUsageResetWindowBackfillBuilder().record(from: summary)
        let history = CodexUsageResetWindowHistory(records: [record])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(history)
        let text = String(decoding: data, as: UTF8.self)

        XCTAssertTrue(text.contains(#""source" : "backfill""#))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("rawLog"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("rawResponse"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("access_token"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("refresh_token"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("authorization"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("cookie"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("session"))
    }

    func testV140ResetWindowHistoryFixtureDecodesAndContainsNoSensitiveMaterial() throws {
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: "v140_reset_window_history",
            withExtension: "json"
        ))
        let data = try Data(contentsOf: url)
        let history = try JSONDecoder().decode(CodexUsageResetWindowHistory.self, from: data)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(history.records.count, 2)
        XCTAssertTrue(history.records.contains { $0.source == .liveCache })
        XCTAssertTrue(history.records.contains { $0.source == .backfill })
        XCTAssertNoSensitiveHistoryMaterial(in: object)
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

    private static func weeklySample(
        recordedAt: Int,
        remainingPercent: Double,
        resetsAt: Int
    ) -> CodexUsageWeeklyHistorySample {
        CodexUsageWeeklyHistorySample(
            recordedAt: recordedAt,
            usedPercent: 100 - remainingPercent,
            remainingPercent: remainingPercent,
            resetsAt: resetsAt,
            windowDurationMins: 10_080
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
