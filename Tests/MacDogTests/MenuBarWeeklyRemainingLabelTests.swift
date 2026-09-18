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

    func testRemainingPercentRoundsToInteger() {
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 0, weeklyUsedPercent: 40.4),
            cacheSnapshot: nil,
            errorMessage: nil,
            usageProviderMode: .codex
        )

        XCTAssertEqual(MenuBarWeeklyRemainingLabel.make(state: state, now: Self.now).text, "60%")
    }

    func testGlanceAttributedTitleUsesElevenPointMonospacedDigits() throws {
        let label = MenuBarWeeklyRemainingLabel.make(
            state: Self.codexState(weeklyUsedPercent: 41),
            now: Self.now
        )
        let attributed = try XCTUnwrap(label.attributedTitle)
        let font = try XCTUnwrap(Self.firstFont(in: attributed))

        XCTAssertEqual(font.pointSize, 11)
        XCTAssertEqual(font, MenuBarWeeklyRemainingLabel.font)
        XCTAssertEqual(label.text, "59%")
    }

    func testNinePercentAndOneHundredPercentShareReservedWidth() {
        let nine = MenuBarWeeklyRemainingLabel.make(
            state: Self.codexState(weeklyUsedPercent: 91),
            now: Self.now
        )
        let hundred = MenuBarWeeklyRemainingLabel.make(
            state: Self.codexState(weeklyUsedPercent: 0),
            now: Self.now
        )

        XCTAssertEqual(nine.text, "9%")
        XCTAssertEqual(hundred.text, "100%")
        XCTAssertEqual(nine.reservedWidth, hundred.reservedWidth, accuracy: 0.5)
        XCTAssertGreaterThan(nine.reservedWidth, 0)
    }

    func testHiddenLabelHasZeroReservedWidthAndNoAttributedTitle() {
        let missing = MenuBarWeeklyRemainingLabel.make(
            state: UsageMonitorState(
                report: nil,
                cacheSnapshot: nil,
                errorMessage: nil,
                usageProviderMode: .codex
            ),
            now: Self.now
        )
        let hidden = MenuBarWeeklyRemainingLabel.make(
            state: Self.codexState(weeklyUsedPercent: 30),
            visible: false,
            now: Self.now
        )

        XCTAssertNil(missing.attributedTitle)
        XCTAssertEqual(missing.reservedWidth, 0)
        XCTAssertNil(hidden.attributedTitle)
        XCTAssertEqual(hidden.reservedWidth, 0)
    }

    func testAttributedTitleReservesTwoPointTrailingGap() throws {
        let attributed = try XCTUnwrap(
            MenuBarWeeklyRemainingLabel.make(
                state: Self.codexState(weeklyUsedPercent: 41),
                now: Self.now
            ).attributedTitle
        )
        var gap: CGFloat = 0
        attributed.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: attributed.length)
        ) { value, _, _ in
            guard let attachment = value as? NSTextAttachment else { return }
            if attachment.bounds.width == MenuBarWeeklyRemainingLabel.trailingGap {
                gap = attachment.bounds.width
            }
        }

        XCTAssertEqual(gap, 2, accuracy: 0.01)
    }

    @MainActor
    func testApplyUsesAttributedGlanceTitleOnStatusItemButton() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }
        let button = try XCTUnwrap(statusItem.button)
        let label = MenuBarWeeklyRemainingLabel.make(
            state: Self.codexState(weeklyUsedPercent: 41),
            now: Self.now
        )

        label.apply(to: button)

        XCTAssertEqual(button.font, MenuBarWeeklyRemainingLabel.font)
        XCTAssertEqual(button.imagePosition, .imageTrailing)
        let font = try XCTUnwrap(Self.firstFont(in: button.attributedTitle))
        XCTAssertEqual(font.pointSize, 11)
        XCTAssertEqual(button.imageHugsTitle, true)
    }

    @MainActor
    func testApplyClearsTitleWidthWhenWeeklyIsHidden() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }
        let button = try XCTUnwrap(statusItem.button)
        MenuBarWeeklyRemainingLabel.make(
            state: Self.codexState(weeklyUsedPercent: 41),
            now: Self.now
        ).apply(to: button)

        MenuBarWeeklyRemainingLabel.make(
            state: Self.codexState(weeklyUsedPercent: 41),
            visible: false,
            now: Self.now
        ).apply(to: button)

        XCTAssertTrue(button.attributedTitle.string.isEmpty)
        XCTAssertEqual(button.title, "")
        XCTAssertEqual(button.imagePosition, .imageOnly)
    }

    private static func firstFont(in attributed: NSAttributedString) -> NSFont? {
        var font: NSFont?
        attributed.enumerateAttribute(.font, in: NSRange(location: 0, length: attributed.length)) { value, _, stop in
            guard let value = value as? NSFont else { return }
            font = value
            stop.pointee = true
        }
        return font
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
