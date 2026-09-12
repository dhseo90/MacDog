import CodexUsageCore
import XCTest
@testable import MacDog

final class CombinedUsageGaugesTests: XCTestCase {
    func testVisibleQueriesFollowDevelopmentOrderWithoutEmptySlots() {
        XCTAssertEqual(UsageGaugeQueryCatalog.visibleQueries.map(\.provider), [.codex, .grok])
        XCTAssertFalse(UsageGaugeQueryCatalog.visibleQueries.contains { $0.provider == .claude })
    }

    func testDisplayOrderPutsMainFirstThenCatalogOrder() {
        let dual = UsageProviderSelection(
            enabled: [.codex, .grok],
            main: .grok,
            detailGraphVisible: true
        )
        XCTAssertEqual(
            UsageGaugeQueryCatalog.displayOrder(main: .grok, selection: dual).map(\.provider),
            [.grok, .codex]
        )
        XCTAssertEqual(
            UsageGaugeQueryCatalog.displayOrder(main: .codex, selection: dual).map(\.provider),
            [.codex, .grok]
        )
        XCTAssertEqual(
            UsageGaugeQueryCatalog.displayOrder(
                main: .grok,
                selection: UsageProviderSelection(enabled: .grok, main: .grok, detailGraphVisible: true)
            ).map(\.provider),
            [.grok]
        )
    }

    func testSingleCodexShowsWeeklyThenFiveHourWithoutGrok() {
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 24, weeklyUsedPercent: 41, weeklyResetsAt: 1_900_003_600),
            cacheSnapshot: nil,
            errorMessage: nil,
            usageProviderMode: .codex
        )
        let gauges = CombinedUsageGauges.make(state: state, now: Self.now)

        XCTAssertEqual(gauges.groups.map(\.provider), [.codex])
        XCTAssertEqual(gauges.items.map(\.title), ["주간", "5시간"])
        XCTAssertEqual(gauges.items.map(\.kind), [.weekly, .fiveHour])
        XCTAssertEqual(gauges.items.map(\.isAuxiliary), [false, false])
        XCTAssertEqual(gauges.items.map(\.provider), [.codex, .codex])
        XCTAssertEqual(
            gauges.items[0].value,
            .ready(usedPercent: 41, remainingPercent: 59, resetsAt: 1_900_003_600)
        )
        XCTAssertEqual(
            gauges.items[1].value,
            .ready(usedPercent: 24, remainingPercent: 76, resetsAt: nil)
        )
    }

    func testSingleGrokShowsWeeklyOnly() throws {
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 99, weeklyUsedPercent: 99),
            cacheSnapshot: nil,
            errorMessage: nil,
            grokUsage: try Self.grokPreview(usedPercent: 55, resetsAt: 1_900_003_600),
            usageProviderMode: .grok
        )
        let gauges = CombinedUsageGauges.make(state: state, now: Self.now)

        XCTAssertEqual(gauges.groups.map(\.provider), [.grok])
        XCTAssertEqual(gauges.items.map(\.title), ["주간"])
        XCTAssertEqual(gauges.items.first?.provider, .grok)
        XCTAssertEqual(gauges.items.first?.isAuxiliary, false)
        XCTAssertEqual(
            gauges.items.first?.value,
            .ready(usedPercent: 55, remainingPercent: 45, resetsAt: 1_900_003_600)
        )
    }

    func testDualCodexMainShowsCodexWindowsThenGrokWeekly() throws {
        let dual = UsageProviderSelection(
            enabled: [.codex, .grok],
            main: .codex,
            detailGraphVisible: true
        )
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 20, weeklyUsedPercent: 30),
            cacheSnapshot: nil,
            errorMessage: nil,
            grokUsage: try Self.grokPreview(usedPercent: 96, resetsAt: 1_900_003_600),
            usageProviderMode: .codex,
            usageProviderSelection: dual
        )
        let gauges = CombinedUsageGauges.make(state: state, now: Self.now)

        XCTAssertEqual(gauges.groups.map(\.provider), [.codex, .grok])
        XCTAssertEqual(gauges.groups.map(\.isAuxiliary), [false, true])
        XCTAssertEqual(gauges.groups[0].items.map(\.title), ["주간", "5시간"])
        XCTAssertEqual(gauges.groups[1].items.map(\.title), ["주간"])
        XCTAssertEqual(gauges.items.map(\.kind), [.weekly, .fiveHour, .weekly])
        XCTAssertEqual(
            gauges.items[2].value,
            .ready(usedPercent: 96, remainingPercent: 4, resetsAt: 1_900_003_600)
        )
        XCTAssertFalse(gauges.items.contains { $0.kind == .fiveHour && $0.provider == .grok })
    }

    func testDualGrokMainShowsGrokWeeklyThenCodexWeeklyWithoutFiveHour() throws {
        let dual = UsageProviderSelection(
            enabled: [.codex, .grok],
            main: .grok,
            detailGraphVisible: true
        )
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 99, weeklyUsedPercent: 33, weeklyResetsAt: 1_900_010_000),
            cacheSnapshot: nil,
            errorMessage: nil,
            grokUsage: try Self.grokPreview(usedPercent: 55, resetsAt: 1_900_003_600),
            usageProviderMode: .grok,
            usageProviderSelection: dual
        )
        let gauges = CombinedUsageGauges.make(state: state, now: Self.now)

        XCTAssertEqual(gauges.groups.map(\.provider), [.grok, .codex])
        XCTAssertEqual(gauges.groups.map(\.isAuxiliary), [false, true])
        XCTAssertEqual(gauges.groups[0].items.map(\.title), ["주간"])
        XCTAssertEqual(gauges.groups[1].items.map(\.title), ["주간"])
        XCTAssertEqual(gauges.items.map(\.provider), [.grok, .codex])
        XCTAssertEqual(gauges.items.map(\.kind), [.weekly, .weekly])
        XCTAssertEqual(gauges.items.map(\.isAuxiliary), [false, true])
        XCTAssertEqual(
            gauges.items[0].value,
            .ready(usedPercent: 55, remainingPercent: 45, resetsAt: 1_900_003_600)
        )
        XCTAssertEqual(
            gauges.items[1].value,
            .ready(usedPercent: 33, remainingPercent: 67, resetsAt: 1_900_010_000)
        )
        XCTAssertFalse(gauges.items.contains { $0.kind == .fiveHour })
    }

    func testAuxiliaryGrokStaleDoesNotUseCodexValues() throws {
        let dual = UsageProviderSelection(
            enabled: [.codex, .grok],
            main: .codex,
            detailGraphVisible: true
        )
        let grok = try Self.grokPreview(usedPercent: 96, resetsAt: 1_900_003_600, staleAfterSeconds: 60)
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 20, weeklyUsedPercent: 30),
            cacheSnapshot: nil,
            errorMessage: nil,
            grokUsage: grok,
            usageProviderMode: .codex,
            usageProviderSelection: dual,
            runnerEvaluationDate: Date(timeIntervalSince1970: 1_900_000_120)
        )
        let gauges = CombinedUsageGauges.make(
            state: state,
            now: Date(timeIntervalSince1970: 1_900_000_120)
        )

        XCTAssertEqual(gauges.groups.map(\.provider), [.codex, .grok])
        XCTAssertEqual(gauges.items[2].value, .unavailable("오래된 cache · 갱신 대기"))
        XCTAssertNotEqual(
            gauges.items[2].value,
            .ready(usedPercent: 20, remainingPercent: 80, resetsAt: nil)
        )
    }

    func testMissingCodexFiveHourIsOmittedWithoutSynthesis() {
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: nil, weeklyUsedPercent: 40),
            cacheSnapshot: nil,
            errorMessage: nil,
            usageProviderMode: .codex
        )
        let gauges = CombinedUsageGauges.make(state: state, now: Self.now)

        XCTAssertEqual(gauges.items.map(\.kind), [.weekly])
        XCTAssertFalse(gauges.items.contains { $0.kind == .fiveHour })
        XCTAssertEqual(
            gauges.items[0].value,
            .ready(usedPercent: 40, remainingPercent: 60, resetsAt: nil)
        )
    }

    func testHidingDetailGraphKeepsGaugesPaceAndStatus() {
        let hidden = UsageProviderSelection(
            enabled: [.codex, .grok],
            main: .codex,
            detailGraphVisible: false
        )
        let shown = UsageProviderSelection(
            enabled: [.codex, .grok],
            main: .grok,
            detailGraphVisible: true
        )
        let hiddenVisibility = UsageTabSectionVisibility.make(mode: .codex, selection: hidden)
        let shownVisibility = UsageTabSectionVisibility.make(mode: .grok, selection: shown)
        let claudeVisibility = UsageTabSectionVisibility.make(mode: .claude, selection: hidden)

        XCTAssertEqual(
            hiddenVisibility,
            UsageTabSectionVisibility(
                showsCombinedGauges: true,
                showsPaceAndCredits: true,
                showsMainWeeklyGraph: false,
                showsDataStatus: true
            )
        )
        XCTAssertTrue(shownVisibility.showsMainWeeklyGraph)
        XCTAssertTrue(shownVisibility.showsCombinedGauges)
        XCTAssertFalse(claudeVisibility.showsCombinedGauges)
        XCTAssertTrue(claudeVisibility.showsMainWeeklyGraph)
    }

    func testCombinedGaugesStayWhenDetailGraphIsHidden() throws {
        let hidden = UsageProviderSelection(
            enabled: [.codex, .grok],
            main: .codex,
            detailGraphVisible: false
        )
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 20, weeklyUsedPercent: 30),
            cacheSnapshot: nil,
            errorMessage: nil,
            grokUsage: try Self.grokPreview(usedPercent: 96, resetsAt: 1_900_003_600),
            usageProviderMode: .codex,
            usageProviderSelection: hidden
        )
        let gauges = CombinedUsageGauges.make(state: state, now: Self.now)

        XCTAssertEqual(gauges.groups.map(\.provider), [.codex, .grok])
        XCTAssertEqual(gauges.items.map(\.kind), [.weekly, .fiveHour, .weekly])
        XCTAssertFalse(
            UsageTabSectionVisibility.make(
                mode: state.usageProviderMode,
                selection: state.usageProviderSelection
            ).showsMainWeeklyGraph
        )
    }

    func testGaugeRowsReserveFixedPercentColumnsAndShowProviderNameOnFirstRowOnly() throws {
        let source = try String(contentsOfFile: "Sources/MacDog/CombinedUsageGauges.swift")
        XCTAssertTrue(source.contains("enum CombinedUsageGaugeMetrics"))
        XCTAssertTrue(source.contains("percentWidth"))
        XCTAssertTrue(source.contains("Text(group.provider.label)"))
        XCTAssertFalse(source.contains("showsProviderLabel"))
        XCTAssertTrue(source.contains("static let percentWidth: CGFloat = 30"))
        XCTAssertTrue(source.contains("static let windowTitleWidth: CGFloat = 34"))
    }

    func testReadyGaugeCopySeparatesUsedAndRemainingWithoutSharedRun() {
        XCTAssertEqual(CombinedUsageGaugeCopy.usedText(usedPercent: 7), "7% 사용")
        XCTAssertEqual(CombinedUsageGaugeCopy.remainingText(remainingPercent: 93), "93% 남음")
        XCTAssertEqual(
            CombinedUsageGaugeCopy.usageText(
                .ready(usedPercent: 42, remainingPercent: 58, resetsAt: 1_900_003_600)
            ),
            "42% 사용 58% 남음"
        )
        XCTAssertEqual(
            CombinedUsageGaugeCopy.usageText(.unavailable("오래된 cache · 갱신 대기")),
            "오래된 cache · 갱신 대기"
        )
    }

    func testClaudeDebugDoesNotBuildVisibleCombinedGauges() throws {
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 20, weeklyUsedPercent: 30),
            cacheSnapshot: nil,
            errorMessage: nil,
            grokUsage: try Self.grokPreview(usedPercent: 96, resetsAt: 1_900_003_600),
            usageProviderMode: .claude
        )

        XCTAssertEqual(CombinedUsageGauges.make(state: state, now: Self.now).items, [])
    }

    private static let now = Date(timeIntervalSince1970: 1_900_000_000)

    private static func grokPreview(
        usedPercent: Double,
        resetsAt: Int?,
        staleAfterSeconds: Int = 900
    ) throws -> GrokUsagePreviewState {
        let weekly = try XCTUnwrap(GrokUsageWeeklyWindow(usedPercent: usedPercent, resetsAt: resetsAt))
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
        weeklyUsedPercent: Double,
        weeklyResetsAt: Int? = nil
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
            resetsAt: weeklyResetsAt
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
