import AppKit
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

    func testPercentSignPreferenceDefaultsOnAndCanBeTurnedOff() throws {
        let suiteName = "MenuBarWeeklyRemainingPercentSign.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertTrue(RunnerPreferences.usageMenuBarWeeklyRemainingPercentSignVisible(defaults: defaults))
        XCTAssertTrue(RunnerPreferences(defaults: defaults).usageMenuBarWeeklyRemainingPercentSignVisible)

        RunnerPreferences.setUsageMenuBarWeeklyRemainingPercentSignVisible(false, defaults: defaults)
        XCTAssertFalse(RunnerPreferences.usageMenuBarWeeklyRemainingPercentSignVisible(defaults: defaults))
        XCTAssertFalse(RunnerPreferences(defaults: defaults).usageMenuBarWeeklyRemainingPercentSignVisible)
    }

    func testMakeOmitsPercentSignWhenDisabled() {
        let state = Self.codexState(weeklyUsedPercent: 41)

        XCTAssertEqual(
            MenuBarWeeklyRemainingLabel.make(state: state, showsPercentSign: true, now: Self.now).text,
            "59%"
        )
        XCTAssertEqual(
            MenuBarWeeklyRemainingLabel.make(state: state, showsPercentSign: false, now: Self.now).text,
            "59"
        )
        XCTAssertNil(
            MenuBarWeeklyRemainingLabel.make(
                state: state,
                visible: false,
                showsPercentSign: true,
                now: Self.now
            ).text
        )
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

    func testPercentUsesNinePointDigitsAndSmallerPercentSign() throws {
        let label = MenuBarWeeklyRemainingLabel.make(
            state: Self.codexState(weeklyUsedPercent: 41),
            now: Self.now
        )
        let attributed = try XCTUnwrap(label.attributedTitle)
        let digitFont = try XCTUnwrap(attributed.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        let signFont = try XCTUnwrap(
            attributed.attribute(.font, at: attributed.length - 1, effectiveRange: nil) as? NSFont
        )
        let elevenPointWidth = NSAttributedString(
            string: "100%",
            attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)]
        ).size().width
        let systemWidth = NSAttributedString(
            string: "100%",
            attributes: [.font: NSFont.systemFont(ofSize: NSFont.systemFontSize)]
        ).size().width

        XCTAssertEqual(label.text, "59%")
        XCTAssertEqual(digitFont.pointSize, 9)
        XCTAssertEqual(signFont.pointSize, 7)
        XCTAssertLessThan(attributed.size().width, elevenPointWidth)
        XCTAssertLessThan(
            MenuBarWeeklyRemainingLabel.attributedPercent("100%").size().width,
            elevenPointWidth
        )
        XCTAssertLessThan(
            MenuBarWeeklyRemainingLabel.attributedPercent("100%").size().width,
            systemWidth
        )
    }

    func testDigitOnlyPlacementKeepsFullNumberVisible() {
        let imageSize = MenuBarIconRenderer.imageSize
        let digits = MenuBarWeeklyRemainingLabel.placement(
            percentText: "59",
            imageSize: imageSize,
            height: 22
        )
        let withSign = MenuBarWeeklyRemainingLabel.placement(
            percentText: "59%",
            imageSize: imageSize,
            height: 22
        )
        let digitWidth = MenuBarWeeklyRemainingLabel.attributedPercent("59").size().width
        let percent = digits.percent!

        XCTAssertEqual(MenuBarWeeklyRemainingLabel.attributedPercent("59").string, "59")
        XCTAssertGreaterThanOrEqual(percent.width, ceil(digitWidth) + 4)
        XCTAssertLessThan(percent.maxX, digits.image.minX)
        XCTAssertEqual(digits.image.minX, percent.maxX + 2, accuracy: 0.01)
        XCTAssertGreaterThan(percent.width, withSign.percent!.width / 2)
    }

    func testPlacementPutsPercentImmediatelyLeftOfDog() throws {
        let imageSize = MenuBarIconRenderer.imageSize
        let visible = MenuBarWeeklyRemainingLabel.placement(
            percentText: "59%",
            imageSize: imageSize,
            height: 22
        )
        let hidden = MenuBarWeeklyRemainingLabel.placement(
            percentText: nil,
            imageSize: imageSize,
            height: 22
        )
        let percent = try XCTUnwrap(visible.percent)

        XCTAssertLessThan(percent.maxX, visible.image.minX)
        XCTAssertEqual(visible.image.minX, percent.maxX + 2, accuracy: 0.01)
        XCTAssertEqual(visible.image.maxX + 1, visible.width, accuracy: 0.01)
        XCTAssertNil(hidden.percent)
        XCTAssertEqual(hidden.image.minX, 1, accuracy: 0.01)
        XCTAssertEqual(
            visible.width,
            MenuBarWeeklyRemainingLabel.compactLength(titleWidth: percent.width, imageWidth: imageSize.width),
            accuracy: 0.01
        )
        XCTAssertEqual(
            hidden.width,
            MenuBarWeeklyRemainingLabel.compactLength(titleWidth: 0, imageWidth: imageSize.width),
            accuracy: 0.01
        )
        XCTAssertGreaterThan(visible.width, hidden.width)
    }

    @MainActor
    func testGlanceViewKeepsDogOnTheRightAndHidesPercentWhenToggledOff() {
        let image = NSImage(size: MenuBarIconRenderer.imageSize)
        let visible = MenuBarGlanceView()
        visible.update(percentText: "59%", image: image)
        let hidden = MenuBarGlanceView()
        hidden.update(percentText: nil, image: image)

        XCTAssertGreaterThan(visible.intrinsicContentSize.width, hidden.intrinsicContentSize.width)
        XCTAssertEqual(
            hidden.intrinsicContentSize.width,
            MenuBarWeeklyRemainingLabel.compactLength(titleWidth: 0, imageWidth: image.size.width),
            accuracy: 0.01
        )
    }

    private static let now = Date(timeIntervalSince1970: 1_900_000_000)

    private static func codexState(weeklyUsedPercent: Double) -> UsageMonitorState {
        UsageMonitorState(
            report: report(fiveHourUsedPercent: 0, weeklyUsedPercent: weeklyUsedPercent),
            cacheSnapshot: nil,
            errorMessage: nil,
            usageProviderMode: .codex
        )
    }

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
