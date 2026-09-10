import XCTest
@testable import MacDog

final class CodexUsageCacheRefreshPolicyTests: XCTestCase {
    func testBundledCacheRefreshAllowsCodexAppServerStartupDelay() {
        XCTAssertEqual(CodexUsageCacheRefreshPolicy.cacheReadInterval, 60)
        XCTAssertEqual(CodexUsageCacheRefreshPolicy.cacheReadTolerance, 6)
        XCTAssertLessThanOrEqual(
            CodexUsageCacheRefreshPolicy.cacheReadTolerance,
            CodexUsageCacheRefreshPolicy.cacheReadInterval * 0.1
        )
        XCTAssertEqual(CodexUsageCacheRefreshPolicy.requestTimeout, 15)
        XCTAssertEqual(CodexUsageCacheRefreshPolicy.processTimeout, 17)
        XCTAssertEqual(CodexUsageCacheRefreshPolicy.minimumRetryInterval, 60)
        XCTAssertEqual(GrokUsageCacheRefreshPolicy.requestTimeout, 15)
        XCTAssertEqual(GrokUsageCacheRefreshPolicy.processTimeout, 40)
        XCTAssertGreaterThan(
            GrokUsageCacheRefreshPolicy.processTimeout,
            GrokUsageCacheRefreshPolicy.requestTimeout
        )
    }

    func testRefreshCommandUsesWriteCacheTimeoutAndOptionalMirror() {
        let codexUsageURL = URL(fileURLWithPath: "/Applications/MacDog.app/Contents/MacOS/codex-usage")

        let commandWithoutWidget = UsageCacheRefreshCommand(
            codexUsageURL: codexUsageURL,
            widgetBundled: false,
            requestTimeout: CodexUsageCacheRefreshPolicy.requestTimeout
        )
        XCTAssertEqual(commandWithoutWidget.executableURL, codexUsageURL)
        XCTAssertEqual(commandWithoutWidget.arguments, [
            "status",
            "--write-cache",
            "--timeout",
            "15"
        ])

        let commandWithWidget = UsageCacheRefreshCommand(
            codexUsageURL: codexUsageURL,
            widgetBundled: true,
            requestTimeout: CodexUsageCacheRefreshPolicy.requestTimeout
        )
        XCTAssertEqual(commandWithWidget.arguments, [
            "status",
            "--write-cache",
            "--mirror-cache",
            "--timeout",
            "15"
        ])
    }

    func testRefreshRetryDecisionHonorsForceAndMinimumInterval() {
        let lastAttempt = Date(timeIntervalSince1970: 1_000)

        XCTAssertTrue(UsageCacheRefreshThrottle.shouldAttempt(
            lastAttempt: nil,
            now: lastAttempt,
            force: false
        ))
        XCTAssertTrue(UsageCacheRefreshThrottle.shouldAttempt(
            lastAttempt: lastAttempt,
            now: Date(timeIntervalSince1970: 1_001),
            force: true
        ))
        XCTAssertFalse(UsageCacheRefreshThrottle.shouldAttempt(
            lastAttempt: lastAttempt,
            now: Date(timeIntervalSince1970: 1_059),
            force: false
        ))
        XCTAssertTrue(UsageCacheRefreshThrottle.shouldAttempt(
            lastAttempt: lastAttempt,
            now: Date(timeIntervalSince1970: 1_060),
            force: false
        ))
    }

    func testLiveCodexRefreshRunsOnlyInCodexMode() {
        XCTAssertTrue(CodexUsageCacheRefreshPolicy.shouldRunLiveRefresh(for: .codex))
        XCTAssertFalse(CodexUsageCacheRefreshPolicy.shouldRunLiveRefresh(for: .grok))
        XCTAssertFalse(CodexUsageCacheRefreshPolicy.shouldRunLiveRefresh(for: .claude))
        XCTAssertTrue(GrokUsageCacheRefreshPolicy.shouldRunLiveRefresh(for: .grok))
        XCTAssertFalse(GrokUsageCacheRefreshPolicy.shouldRunLiveRefresh(for: .codex))
        XCTAssertFalse(GrokUsageCacheRefreshPolicy.shouldRunLiveRefresh(for: .claude))
    }

    func testLiveRefreshRunsIndependentlyForEnabledVisibleProviders() {
        let dual = UsageProviderSelection(
            enabled: [.codex, .grok],
            main: .grok,
            detailGraphVisible: true
        )
        let grokOnly = UsageProviderSelection(enabled: .grok, main: .grok, detailGraphVisible: true)

        XCTAssertTrue(CodexUsageCacheRefreshPolicy.shouldRunLiveRefresh(for: dual))
        XCTAssertTrue(GrokUsageCacheRefreshPolicy.shouldRunLiveRefresh(for: dual))
        XCTAssertTrue(CodexUsageCacheRefreshPolicy.shouldRunLiveRefresh(for: .grok, selection: dual))
        XCTAssertTrue(GrokUsageCacheRefreshPolicy.shouldRunLiveRefresh(for: .codex, selection: dual))
        XCTAssertFalse(CodexUsageCacheRefreshPolicy.shouldRunLiveRefresh(for: grokOnly))
        XCTAssertTrue(GrokUsageCacheRefreshPolicy.shouldRunLiveRefresh(for: grokOnly))
        XCTAssertFalse(CodexUsageCacheRefreshPolicy.shouldRunLiveRefresh(for: .claude, selection: dual))
        XCTAssertFalse(GrokUsageCacheRefreshPolicy.shouldRunLiveRefresh(for: .claude, selection: dual))
    }

    func testGrokRefreshCommandWritesCacheWithoutMirror() {
        let command = UsageCacheRefreshCommand.grokWriteCache(
            grokUsageURL: URL(fileURLWithPath: "/Applications/MacDog.app/Contents/MacOS/macdog-grok-usage")
        )
        XCTAssertEqual(command.arguments, [
            "status",
            "--write-cache",
            "--timeout",
            "15"
        ])
    }

    func testRefreshRunnerTerminatesProcessWhenProviderTaskIsCancelled() async throws {
        let command = UsageCacheRefreshCommand(
            executableURL: URL(fileURLWithPath: "/bin/sleep"),
            arguments: ["10"]
        )
        let task = Task {
            await UsageCacheRefreshRunner.run(command: command, processTimeout: 10)
        }
        try await Task.sleep(nanoseconds: 100_000_000)

        let cancelledAt = Date()
        task.cancel()
        await task.value

        XCTAssertLessThan(Date().timeIntervalSince(cancelledAt), 1)
    }
}
