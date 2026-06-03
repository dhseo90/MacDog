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

    func testDefaultSharedFileURLUsesStableAppGroupFallback() {
        let url = CodexUsageCacheStore.defaultSharedFileURL()
        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: CodexUsageCacheStore.defaultAppGroupIdentifier
        )

        XCTAssertEqual(url.lastPathComponent, "usage.json")
        if let containerURL {
            XCTAssertEqual(url, containerURL.appendingPathComponent("usage.json"))
        } else {
            XCTAssertTrue(url.path.contains("/Library/Group Containers/group.com.dhseo.macdog.MacDog/usage.json"))
        }
    }

    func testDefaultMirroredFileURLsIncludeDefaultAndAvailableSharedCachePaths() {
        let urls = CodexUsageCacheStore.defaultMirroredFileURLs()
        let paths = Set(urls.map { $0.standardizedFileURL.path })

        XCTAssertEqual(urls.count, paths.count)
        XCTAssertTrue(paths.contains(CodexUsageCacheStore.defaultFileURL().standardizedFileURL.path))
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: CodexUsageCacheStore.defaultAppGroupIdentifier
        ) {
            XCTAssertTrue(paths.contains(containerURL.appendingPathComponent("usage.json").standardizedFileURL.path))
        } else {
            XCTAssertFalse(paths.contains(CodexUsageCacheStore.defaultSharedFileURL().standardizedFileURL.path))
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

    func testWriteSuccessAppendsWeeklyHistoryNextToCacheFile() throws {
        let fileURL = temporaryFileURL()
        let now = 1_800_000_000
        let resetsAt = now + 345_600
        let store = CodexUsageCacheStore(fileURL: fileURL, dateProvider: {
            Date(timeIntervalSince1970: TimeInterval(now))
        })

        try store.writeSuccess(
            report: Self.historyReport(weeklyUsedPercent: 38, weeklyResetsAt: resetsAt),
            staleAfterSeconds: 60
        )

        let historyURL = CodexUsageWeeklyHistoryStore.defaultFileURL(adjacentToCacheFileURL: fileURL)
        let history = try CodexUsageWeeklyHistoryStore(fileURL: historyURL).read()

        XCTAssertEqual(history.schemaVersion, CodexUsageWeeklyHistory.currentSchemaVersion)
        XCTAssertEqual(history.samples.count, 1)
        XCTAssertEqual(history.samples.first?.recordedAt, now)
        XCTAssertEqual(history.samples.first?.usedPercent, 38)
        XCTAssertEqual(history.samples.first?.remainingPercent, 62)
        XCTAssertEqual(history.samples.first?.resetsAt, resetsAt)
        XCTAssertEqual(history.samples.first?.windowDurationMins, 10_080)
    }

    func testWeeklyHistorySkipsDenseUnchangedSamplesButKeepsMaterialChanges() throws {
        let fileURL = temporaryHistoryFileURL()
        let store = CodexUsageWeeklyHistoryStore(fileURL: fileURL)
        let reset = 2_000

        XCTAssertTrue(try store.append(Self.weeklySample(recordedAt: 1_000, remainingPercent: 80, resetsAt: reset)))
        XCTAssertFalse(try store.append(Self.weeklySample(recordedAt: 1_060, remainingPercent: 79.9, resetsAt: reset)))
        XCTAssertTrue(try store.append(Self.weeklySample(recordedAt: 1_120, remainingPercent: 79.6, resetsAt: reset)))

        let history = try store.read()
        XCTAssertEqual(history.samples.map(\.remainingPercent), [80, 79.6])
    }

    func testWeeklyHistoryKeepsNewResetWindowEvenWhenCloseTogether() throws {
        let fileURL = temporaryHistoryFileURL()
        let store = CodexUsageWeeklyHistoryStore(fileURL: fileURL)

        XCTAssertTrue(try store.append(Self.weeklySample(recordedAt: 1_000, remainingPercent: 80, resetsAt: 2_000)))
        XCTAssertTrue(try store.append(Self.weeklySample(recordedAt: 1_060, remainingPercent: 80, resetsAt: 3_000)))

        XCTAssertEqual(try store.read().samples.map(\.resetsAt), [2_000, 3_000])
    }

    func testWeeklyHistoryPrunesSamplesOlderThanRetentionWindow() throws {
        let fileURL = temporaryHistoryFileURL()
        let store = CodexUsageWeeklyHistoryStore(fileURL: fileURL)
        let newRecordedAt = CodexUsageWeeklyHistoryStore.defaultRetentionSeconds + 10

        XCTAssertTrue(try store.append(Self.weeklySample(recordedAt: 0, remainingPercent: 90, resetsAt: 10_080 * 60)))
        XCTAssertTrue(try store.append(Self.weeklySample(recordedAt: newRecordedAt, remainingPercent: 70, resetsAt: newRecordedAt + 10_080 * 60)))

        let history = try store.read()
        XCTAssertEqual(history.samples.count, 1)
        XCTAssertEqual(history.samples.first?.recordedAt, newRecordedAt)
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

    func testFailureSnapshotDropsInvalidExistingReport() throws {
        let fileURL = temporaryFileURL()
        var now = 1_779_800_000
        let store = CodexUsageCacheStore(fileURL: fileURL, dateProvider: {
            Date(timeIntervalSince1970: TimeInterval(now))
        })
        let invalidSnapshot = CodexUsageCacheSnapshot(
            cachedAt: now,
            staleAfterSeconds: 60,
            report: Self.incompleteCodexReport(),
            error: nil
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(invalidSnapshot).write(to: fileURL)

        now += 10
        try store.writeFailure(message: "codex usage windows unavailable", staleAfterSeconds: 60)
        let snapshot = try store.read()

        XCTAssertNil(snapshot.report)
        XCTAssertEqual(snapshot.error?.message, "codex usage windows unavailable")
        XCTAssertTrue(snapshot.isStale(now: Date(timeIntervalSince1970: 1_779_800_011)))
    }

    func testWriteSuccessRejectsInvalidCodexReport() throws {
        let fileURL = temporaryFileURL()
        let store = CodexUsageCacheStore(fileURL: fileURL)

        XCTAssertThrowsError(try store.writeSuccess(report: Self.incompleteCodexReport())) { error in
            XCTAssertTrue(error.localizedDescription.contains("missing required codex usage windows"))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testFailureSnapshotRedactsSensitiveSessionMaterial() throws {
        let fileURL = temporaryFileURL()
        let store = CodexUsageCacheStore(fileURL: fileURL, dateProvider: {
            Date(timeIntervalSince1970: 1_779_800_000)
        })

        try store.writeFailure(
            message: """
            request failed access_token=abc123 refresh_token:'def456' accessToken=camel123 refreshToken:"camel456" \
            session_id=session987 sessionId:'camel789' idToken=json000 apiKey=api111 clientSecret=client222 \
            Authorization: Bearer secret789 Authorization: Basic basic333 Cookie: sid=cookie444; other=value
            """,
            staleAfterSeconds: 60
        )

        let snapshot = try store.read()
        let message = try XCTUnwrap(snapshot.error?.message)
        XCTAssertTrue(message.contains("<redacted>"))
        XCTAssertFalse(message.contains("abc123"))
        XCTAssertFalse(message.contains("def456"))
        XCTAssertFalse(message.contains("secret789"))
        XCTAssertFalse(message.contains("session987"))
        XCTAssertFalse(message.contains("camel123"))
        XCTAssertFalse(message.contains("camel456"))
        XCTAssertFalse(message.contains("camel789"))
        XCTAssertFalse(message.contains("json000"))
        XCTAssertFalse(message.contains("api111"))
        XCTAssertFalse(message.contains("client222"))
        XCTAssertFalse(message.contains("basic333"))
        XCTAssertFalse(message.contains("cookie444"))

        let data = try Data(contentsOf: fileURL)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains("abc123"))
        XCTAssertFalse(text.contains("def456"))
        XCTAssertFalse(text.contains("secret789"))
        XCTAssertFalse(text.contains("session987"))
        XCTAssertFalse(text.contains("camel123"))
        XCTAssertFalse(text.contains("camel456"))
        XCTAssertFalse(text.contains("camel789"))
        XCTAssertFalse(text.contains("json000"))
        XCTAssertFalse(text.contains("api111"))
        XCTAssertFalse(text.contains("client222"))
        XCTAssertFalse(text.contains("basic333"))
        XCTAssertFalse(text.contains("cookie444"))
    }

    private func makeReport() throws -> CodexUsageReport {
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: "rate_limits_response",
            withExtension: "json"
        ))
        let data = try Data(contentsOf: url)
        let response = try JSONDecoder().decode(RateLimitsResponse.self, from: data)
        return try CodexUsageReportBuilder(dateProvider: {
            Date(timeIntervalSince1970: 1_779_700_000)
        }).build(from: response)
    }

    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("usage.json")
    }

    private func temporaryHistoryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("usage-weekly-history.json")
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

    private static func historyReport(
        weeklyUsedPercent: Double,
        weeklyResetsAt: Int
    ) -> CodexUsageReport {
        let fiveHour = UsageWindowReport(
            kind: .fiveHour,
            usedPercent: 12,
            remainingPercent: 88,
            windowDurationMins: 300,
            resetsAt: nil
        )
        let weekly = UsageWindowReport(
            kind: .weekly,
            usedPercent: weeklyUsedPercent,
            remainingPercent: 100 - weeklyUsedPercent,
            windowDurationMins: 10_080,
            resetsAt: weeklyResetsAt
        )
        let limit = UsageLimitReport(
            limitId: "codex",
            limitName: "Codex",
            primary: fiveHour,
            secondary: weekly,
            credits: nil,
            planType: "pro",
            rateLimitReachedType: nil
        )
        return CodexUsageReport(
            generatedAt: 0,
            source: "test",
            planType: "pro",
            credits: nil,
            rateLimitReachedType: nil,
            limits: ["codex": limit]
        )
    }

    private static func incompleteCodexReport() -> CodexUsageReport {
        let limit = UsageLimitReport(
            limitId: "codex",
            limitName: nil,
            primary: UsageWindowReport(
                kind: .other,
                usedPercent: 0,
                remainingPercent: 100,
                windowDurationMins: nil,
                resetsAt: nil
            ),
            secondary: nil,
            credits: CreditsSnapshot(hasCredits: false, unlimited: false, balance: "0"),
            planType: "pro",
            rateLimitReachedType: nil
        )
        return CodexUsageReport(
            generatedAt: 1_779_800_000,
            source: "codex-app-server",
            planType: "pro",
            credits: limit.credits,
            rateLimitReachedType: nil,
            limits: ["codex": limit]
        )
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
