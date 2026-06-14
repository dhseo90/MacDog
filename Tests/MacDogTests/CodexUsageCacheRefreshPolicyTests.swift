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
}
