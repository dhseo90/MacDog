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
