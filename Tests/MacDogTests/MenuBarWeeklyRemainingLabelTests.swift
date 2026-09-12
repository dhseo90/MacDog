import CodexUsageCore
import XCTest
@testable import MacDog

final class MenuBarWeeklyRemainingLabelTests: XCTestCase {
    func testCodexMainShowsWeeklyRemainingIgnoringFiveHour() {
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 90, weeklyUsedPercent: 41),
            cacheSnapshot: nil,
            errorMessage: nil,
            usageProviderMode: .codex
        )

        XCTAssertEqual(MenuBarWeeklyRemainingLabel.make(state: state, now: Self.now).text, "59%")
    }

    func testGrokMainShowsWeeklyRemaining() throws {
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 99, weeklyUsedPercent: 99),
            cacheSnapshot: nil,
            errorMessage: nil,
            grokUsage: try Self.grokPreview(usedPercent: 55),
            usageProviderMode: .grok
        )

        XCTAssertEqual(MenuBarWeeklyRemainingLabel.make(state: state, now: Self.now).text, "45%")
    }

    func testDualCodexMainIgnoresAuxiliaryGrokWeekly() throws {
        let dual = UsageProviderSelection(
            enabled: [.codex, .grok],
            main: .codex,
            detailGraphVisible: true
        )
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 20, weeklyUsedPercent: 30),
            cacheSnapshot: nil,
            errorMessage: nil,
            grokUsage: try Self.grokPreview(usedPercent: 96),
            usageProviderMode: .codex,
            usageProviderSelection: dual
        )

        XCTAssertEqual(MenuBarWeeklyRemainingLabel.make(state: state, now: Self.now).text, "70%")
    }

    func testDualGrokMainIgnoresAuxiliaryCodexWeekly() throws {
        let dual = UsageProviderSelection(
            enabled: [.codex, .grok],
            main: .grok,
            detailGraphVisible: true
        )
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 10, weeklyUsedPercent: 10),
            cacheSnapshot: nil,
            errorMessage: nil,
            grokUsage: try Self.grokPreview(usedPercent: 55),
            usageProviderMode: .grok,
            usageProviderSelection: dual
        )

        XCTAssertEqual(MenuBarWeeklyRemainingLabel.make(state: state, now: Self.now).text, "45%")
    }

    func testMissingWeeklyHidesLabelWithoutSynthesis() {
        let state = UsageMonitorState(
            report: nil,
            cacheSnapshot: nil,
            errorMessage: nil,
            usageProviderMode: .codex
        )

        XCTAssertNil(MenuBarWeeklyRemainingLabel.make(state: state, now: Self.now).text)
    }

    func testStaleGrokWeeklyHidesLabel() throws {
        let grok = try Self.grokPreview(usedPercent: 40, staleAfterSeconds: 60)
        let state = UsageMonitorState(
            report: nil,
            cacheSnapshot: nil,
            errorMessage: nil,
            grokUsage: grok,
            usageProviderMode: .grok,
            runnerEvaluationDate: Date(timeIntervalSince1970: 1_900_000_120)
        )

        XCTAssertNil(
            MenuBarWeeklyRemainingLabel.make(
                state: state,
                now: Date(timeIntervalSince1970: 1_900_000_120)
            ).text
        )
    }

    func testClaudeDebugHidesLabel() throws {
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 20, weeklyUsedPercent: 30),
            cacheSnapshot: nil,
            errorMessage: nil,
            grokUsage: try Self.grokPreview(usedPercent: 40),
            usageProviderMode: .claude
        )

        XCTAssertNil(MenuBarWeeklyRemainingLabel.make(state: state, now: Self.now).text)
    }

    func testHiddenPreferenceHidesLabelWhenWeeklyIsReady() {
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 20, weeklyUsedPercent: 30),
            cacheSnapshot: nil,
            errorMessage: nil,
            usageProviderMode: .codex
        )

        XCTAssertNil(
            MenuBarWeeklyRemainingLabel.make(state: state, visible: false, now: Self.now).text
        )
        XCTAssertEqual(
            MenuBarWeeklyRemainingLabel.make(state: state, visible: true, now: Self.now).text,
            "70%"
        )
    }

    func testMenuBarWeeklyRemainingPreferenceDefaultsOnAndCanBeTurnedOff() throws {
        let suiteName = "MenuBarWeeklyRemainingVisible.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertTrue(RunnerPreferences.usageMenuBarWeeklyRemainingVisible(defaults: defaults))
        XCTAssertTrue(RunnerPreferences(defaults: defaults).usageMenuBarWeeklyRemainingVisible)

        RunnerPreferences.setUsageMenuBarWeeklyRemainingVisible(false, defaults: defaults)
        XCTAssertFalse(RunnerPreferences.usageMenuBarWeeklyRemainingVisible(defaults: defaults))
        XCTAssertFalse(RunnerPreferences(defaults: defaults).usageMenuBarWeeklyRemainingVisible)
    }

    func testRemainingPercentRoundsToInteger() {
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 0, weeklyUsedPercent: 40.4),
            cacheSnapshot: nil,
            errorMessage: nil,
            usageProviderMode: .codex
        )

        XCTAssertEqual(MenuBarWeeklyRemainingLabel.make(state: state, now: Self.now).text, "60%")
    }

    private static let now = Date(timeIntervalSince1970: 1_900_000_000)

    private static func grokPreview(
        usedPercent: Double,
        staleAfterSeconds: Int = 900
    ) throws -> GrokUsagePreviewState {
        let weekly = try XCTUnwrap(GrokUsageWeeklyWindow(usedPercent: usedPercent, resetsAt: 1_900_003_600))
        return GrokUsagePreviewState(
            isEnabled: true,
            cacheSnapshot: GrokUsageCacheSnapshot(
                fetchedAt: 1_900_000_000,
                lastUsageObservedAt: 1_900_000_000,
                staleAfterSeconds: staleAfterSeconds,
                weekly: weekly,
                issue: nil
            ),
            history: .empty,
            loadIssue: nil
        )
    }

    private static func report(
        fiveHourUsedPercent: Double?,
        weeklyUsedPercent: Double
    ) -> CodexUsageReport {
        let fiveHour = fiveHourUsedPercent.map {
            UsageWindowReport(
                kind: .fiveHour,
                usedPercent: $0,
                remainingPercent: 100 - $0,
                windowDurationMins: 300,
                resetsAt: nil
            )
        }
        let weekly = UsageWindowReport(
            kind: .weekly,
            usedPercent: weeklyUsedPercent,
            remainingPercent: 100 - weeklyUsedPercent,
            windowDurationMins: 10_080,
            resetsAt: 1_900_003_600
        )
        let limit = UsageLimitReport(
            limitId: "codex",
            limitName: "Codex",
            primary: fiveHour ?? weekly,
            secondary: fiveHour == nil ? nil : weekly,
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
}
