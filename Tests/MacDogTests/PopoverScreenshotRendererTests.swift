import AppKit
import CodexUsageCore
import SwiftUI
import XCTest
@testable import MacDog

@MainActor
final class PopoverScreenshotRendererTests: XCTestCase {
    func testUsagePopoverFirstFrameFillsScreenshotCanvas() {
        let now = MacDogDemoData.readmeScreenshotTimestamp
        let view = UsagePopoverView(
            state: MacDogDemoData.state(
                selection: UsageProviderSelection(
                    enabled: .codex,
                    main: .codex,
                    detailGraphVisible: true
                ),
                now: now
            ),
            notificationAuthorizationClient: StaticUsageNotificationAuthorizationClient(status: .notDetermined),
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )

        let image = render(view: view, size: NSSize(width: 370, height: 408), scale: 2)

        XCTAssertGreaterThan(
            screenshotColorDistance(in: image, from: CGPoint(x: 0.02, y: 0.02), to: CGPoint(x: 0.89, y: 0.12)),
            0.12
        )
        XCTAssertGreaterThan(
            screenshotColorDistance(in: image, from: CGPoint(x: 0.02, y: 0.02), to: CGPoint(x: 0.16, y: 0.30)),
            0.12
        )
    }

    func testUsagePopoverRendersSingleCodexMainDualGrokMainDualAndGraphHiddenStates() {
        let now = MacDogDemoData.readmeScreenshotTimestamp
        let cases: [(String, UsageProviderSelection, Int)] = [
            (
                "single-codex",
                UsageProviderSelection(enabled: .codex, main: .codex, detailGraphVisible: true),
                2
            ),
            (
                "codex-main-dual",
                UsageProviderSelection(enabled: [.codex, .grok], main: .codex, detailGraphVisible: true),
                3
            ),
            (
                "grok-main-dual",
                UsageProviderSelection(enabled: [.codex, .grok], main: .grok, detailGraphVisible: true),
                2
            ),
            (
                "graph-hidden",
                UsageProviderSelection(enabled: [.codex, .grok], main: .codex, detailGraphVisible: false),
                3
            )
        ]

        for (name, selection, gaugeCount) in cases {
            let state = MacDogDemoData.state(selection: selection, now: now)
            let gauges = CombinedUsageGauges.make(
                state: state,
                now: Date(timeIntervalSince1970: TimeInterval(now))
            )
            XCTAssertEqual(gauges.items.count, gaugeCount, name)
            XCTAssertEqual(
                UsageTabSectionVisibility.make(mode: state.usageProviderMode, selection: selection)
                    .showsMainWeeklyGraph,
                selection.detailGraphVisible,
                name
            )

            let image = renderUsagePopover(state)
            XCTAssertGreaterThan(image.tiffRepresentation?.count ?? 0, 100, name)
            XCTAssertGreaterThan(
                screenshotColorDistance(
                    in: image,
                    from: CGPoint(x: 0.02, y: 0.02),
                    to: CGPoint(x: 0.89, y: 0.12)
                ),
                0.12,
                name
            )
        }
    }

    func testSettingsPanelRendersVisibleProviderCheckboxesWithoutSubTabs() {
        let view = SettingsPanel(
            privilegedHelperInstallSnapshot: .missing,
            onAction: { _ in },
            onPreferencesChanged: {},
            notificationAuthorizationClient: StaticUsageNotificationAuthorizationClient(status: .notDetermined)
        )
        let image = render(view: view, size: NSSize(width: 292, height: 360), scale: 2)
        XCTAssertGreaterThan(image.tiffRepresentation?.count ?? 0, 100)
    }

    func testClaudeUsageWaitingPartialReadyStaleAndErrorStatesRender() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let previews = [
            ClaudeUsagePreviewState(
                isEnabled: true,
                cacheSnapshot: nil,
                history: .empty,
                loadIssue: nil
            ),
            Self.claudePreview(now: now, includeSevenDay: false),
            Self.claudePreview(now: now),
            Self.claudePreview(now: now, observedAtOffset: -1_000, staleAfterSeconds: 60),
            Self.claudePreview(now: now, issueCode: "status_line_decode_failed")
        ]

        for preview in previews {
            let view = ClaudeUsagePreviewPanel(preview: preview, now: now)
                .frame(width: 254, alignment: .topLeading)
            let image = render(view: view, size: NSSize(width: 254, height: 310), scale: 2)
            XCTAssertGreaterThan(image.tiffRepresentation?.count ?? 0, 100)
        }

        let source = try String(contentsOfFile: "Sources/MacDog/Popover/ClaudeUsagePreviewPanel.swift")
        XCTAssertTrue(source.contains("Claude 사용량"))
        XCTAssertTrue(source.contains("% 사용 · "))
        XCTAssertTrue(source.contains("% 남음"))
        XCTAssertTrue(source.contains("Claude 연결 필요"))
        XCTAssertTrue(source.contains("연결 명령 복사"))
        XCTAssertTrue(source.contains("connectionGuide.standaloneCommand"))
        XCTAssertFalse(source.contains("PREVIEW"))
        XCTAssertFalse(source.contains("Claude Preview"))
        XCTAssertFalse(source.contains("CodexResetCreditsBlock"))
    }

    func testClaudeHistoryCurrentPastCompareGraphsExportProviderLabeledPNG() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let preview = Self.claudePreview(now: now)
        let currentReset = try XCTUnwrap(preview.usage?.sevenDay?.resetsAt)
        let pastReset = currentReset - ClaudeUsageWindowKind.sevenDay.windowDurationMins * 60

        for mode in ClaudeUsageHistoryGraphMode.allCases {
            let data = CodexUsageGraphImageExporter.pngData(
                for: ClaudeUsageGraphSnapshotView(
                    kind: .sevenDay,
                    mode: mode,
                    currentResetsAt: currentReset,
                    pastResetsAt: pastReset,
                    history: preview.history
                ),
                size: CGSize(width: 520, height: 180),
                scale: 2
            )
            XCTAssertEqual(data?.prefix(8), Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
        }

        let source = try String(contentsOfFile: "Sources/MacDog/Popover/ClaudeUsagePreviewPanel.swift")
        XCTAssertTrue(source.contains("macdog-claude-usage-"))
        XCTAssertTrue(source.contains("Claude ·"))
    }

    func testCodexResetCreditsBlockBuildsCompactLayout() {
        let resetCredits = RateLimitResetCreditsSummary(
            availableCount: 3,
            credits: [
                RateLimitResetCredit(
                    id: "credit_1",
                    status: "available",
                    resetType: "manual",
                    expiresAt: "2027-01-16T09:30:00Z"
                ),
                RateLimitResetCredit(
                    id: "credit_2",
                    status: "available",
                    resetType: "manual",
                    expiresAt: "2027-01-17T11:00:00Z"
                ),
                RateLimitResetCredit(
                    id: "credit_3",
                    status: "available",
                    resetType: "manual",
                    expiresAt: "2027-01-18T12:30:00Z"
                )
            ]
        )

        XCTAssertEqual(CodexResetCreditTextFormatter.countText(for: resetCredits), "3장")
        XCTAssertEqual(
            CodexResetCreditTextFormatter.expirySummary(for: resetCredits, timeZone: TimeZone(secondsFromGMT: 9 * 60 * 60)!),
            "먼저 1/16 18:30까지 · 1/17 20:00까지 · 1/18 21:30까지"
        )
        XCTAssertEqual(
            CodexResetCreditTextFormatter.expiryText(
                for: RateLimitResetCredit(
                    id: "live_credit",
                    status: "available",
                    resetType: "manual",
                    expiresAt: "2026-07-18T00:34:01.707337Z"
                ),
                timeZone: TimeZone(secondsFromGMT: 9 * 60 * 60)!
            ),
            "7/18 09:34까지"
        )

        let view = CodexResetCreditsBlock(resetCredits: resetCredits)

        let contentWidth = MacDogPopoverLayout.contentSurfaceSize.width -
            (MacDogPopoverLayout.contentPadding * 2)
        let hostingView = NSHostingView(rootView: view.frame(width: contentWidth))
        hostingView.frame = NSRect(x: 0, y: 0, width: contentWidth, height: 96)
        hostingView.layoutSubtreeIfNeeded()

        XCTAssertLessThanOrEqual(hostingView.fittingSize.height, 96)
    }

    func testCodexResetCreditsBlockKeepsFiveCreditsCompactAndSortedByExpiry() {
        let resetCredits = Self.resetCredits(count: 5, shuffled: true)

        XCTAssertEqual(CodexResetCreditTextFormatter.countText(for: resetCredits), "5장")
        XCTAssertEqual(
            CodexResetCreditTextFormatter.expirySummary(for: resetCredits, timeZone: TimeZone(secondsFromGMT: 9 * 60 * 60)!),
            "먼저 7/18 09:34까지 · 7/27 08:47까지 · 8/1 04:07까지 · 8/5 12:20까지 · 8/9 21:10까지"
        )

        let view = CodexResetCreditsBlock(resetCredits: resetCredits)

        let contentWidth = MacDogPopoverLayout.contentSurfaceSize.width -
            (MacDogPopoverLayout.contentPadding * 2)
        let hostingView = NSHostingView(rootView: view.frame(width: contentWidth))
        hostingView.frame = NSRect(x: 0, y: 0, width: contentWidth, height: 96)
        hostingView.layoutSubtreeIfNeeded()

        XCTAssertLessThanOrEqual(hostingView.fittingSize.height, 96)
    }

    func testCodexResetCreditFormatterUsesActionableCopyWhenExpiryDetailsAreUnavailable() {
        let resetCredits = RateLimitResetCreditsSummary(availableCount: 2)

        XCTAssertEqual(CodexResetCreditTextFormatter.countText(for: resetCredits), "2장")
        XCTAssertEqual(
            CodexResetCreditTextFormatter.expirySummary(for: resetCredits),
            "만료일 갱신 필요"
        )
    }

    func testCodexUsagePanelKeepsPrimarySectionsVisibleWithoutDisclosure() throws {
        let state = UsageMonitorState(
            report: Self.codexReportWithThreeResetCreditExpiries(),
            cacheSnapshot: nil,
            weeklyUsageHistory: .empty,
            resetWindowHistory: .empty,
            errorMessage: nil,
            systemMetrics: .unavailable
        )
        let view = CodexUsagePanel(state: state)

        let contentWidth = MacDogPopoverLayout.contentSurfaceSize.width -
            (MacDogPopoverLayout.contentPadding * 2)
        let contentHeight = MacDogPopoverLayout.nonScrollableContentHeight
        let hostingView = NSHostingView(rootView: view.frame(width: contentWidth))
        hostingView.frame = NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
        hostingView.layoutSubtreeIfNeeded()

        XCTAssertLessThanOrEqual(hostingView.fittingSize.height, contentHeight)

        let source = try String(contentsOfFile: "Sources/MacDog/Popover/CodexUsagePanel.swift")
        XCTAssertTrue(
            source.contains("CodexUsageSummaryInline("),
            "Codex tab should keep the existing current risk summary visible"
        )
        XCTAssertTrue(
            source.contains("summary.notificationThresholdSummary"),
            "Codex tab should keep the existing notification threshold visible"
        )
        XCTAssertTrue(
            source.contains("spacing: CodexUsagePanelLayout.sectionSpacing"),
            "Codex tab should separate current usage, reset credits, history, and data status as major sections"
        )
        XCTAssertTrue(source.contains("CodexWeeklyPacemakerBlock("))
    }

    func testCodexUsagePanelKeepsWeeklyContentVisibleWhenFiveHourIsUnavailable() throws {
        let report = Self.weeklyOnlyCodexReport()
        let snapshot = CodexUsageCacheSnapshot(
            cachedAt: report.generatedAt,
            staleAfterSeconds: 120,
            report: report,
            error: nil
        )
        let state = UsageMonitorState(
            report: report,
            cacheSnapshot: snapshot,
            weeklyUsageHistory: .empty,
            resetWindowHistory: .empty,
            errorMessage: nil,
            displayBasis: .fiveHour,
            systemMetrics: .unavailable,
            runnerEvaluationDate: Date(timeIntervalSince1970: TimeInterval(report.generatedAt))
        )
        let view = CodexUsagePanel(state: state)
        let contentWidth = MacDogPopoverLayout.contentSurfaceSize.width -
            (MacDogPopoverLayout.contentPadding * 2)
        let contentHeight = MacDogPopoverLayout.nonScrollableContentHeight
        let hostingView = NSHostingView(rootView: view.frame(width: contentWidth))
        hostingView.frame = NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
        hostingView.layoutSubtreeIfNeeded()

        XCTAssertNotNil(state.codexPanelSummary())
        XCTAssertEqual(state.selectedWindowStatus?.label, "주간")
        XCTAssertLessThanOrEqual(hostingView.fittingSize.height, contentHeight)

        let rowSource = try String(
            contentsOfFile: "Sources/MacDog/Popover/WeeklyRemainingHistoryViews.swift"
        )
        let stateSource = try String(contentsOfFile: "Sources/MacDog/UsageMonitorState.swift")
        XCTAssertTrue(rowSource.contains("현재 제공되지 않음"))
        XCTAssertTrue(rowSource.contains("if window != nil"))
        XCTAssertTrue(stateSource.contains("guard codexLimit?.fiveHour != nil"))
        XCTAssertFalse(state.codexDataStatus.title.contains("오류"))
    }

    func testPlanTransitionUIIsRemovedAndPacemakerRemains() throws {
        let panelSource = try String(contentsOfFile: "Sources/MacDog/Popover/CodexUsagePanel.swift")
        let settingsSource = try String(contentsOfFile: "Sources/MacDog/Popover/SettingsPanel.swift")
        let graphSource = try String(
            contentsOfFile: "Sources/MacDog/Popover/WeeklyRemainingHistoryViews.swift"
        )
        XCTAssertTrue(panelSource.contains("CodexWeeklyPacemakerBlock("))
        XCTAssertFalse(panelSource.contains("CodexPlanTransition"))
        XCTAssertFalse(settingsSource.contains("플랜 전환"))
        XCTAssertFalse(graphSource.contains("epochBoundary"))
        XCTAssertFalse(graphSource.contains("P90"))
    }

    func testSelectedProviderUIUsesOnlySettingsModePicker() throws {
        let settingsSource = try String(contentsOfFile: "Sources/MacDog/Popover/SettingsPanel.swift")
        let popoverSource = try String(contentsOfFile: "Sources/MacDog/UsagePopoverView.swift")
        let claudePanelSource = try String(contentsOfFile: "Sources/MacDog/Popover/ClaudeUsagePreviewPanel.swift")
        let controllerSource = try String(contentsOfFile: "Sources/MacDog/MenuBarController.swift")
        let grokPanelSource = try String(contentsOfFile: "Sources/MacDog/Popover/GrokUsagePanel.swift")

        XCTAssertFalse(settingsSource.contains("Picker(\"사용량 mode\""))
        XCTAssertTrue(settingsSource.contains("UsageProviderMode.visibleCases"))
        XCTAssertTrue(settingsSource.contains("활성 provider"))
        XCTAssertTrue(settingsSource.contains("Picker(\"메인 provider\""))
        XCTAssertTrue(settingsSource.contains("상세 그래프 표시"))
        XCTAssertTrue(settingsSource.contains("메뉴바에 주간 잔여율 표시"))
        XCTAssertTrue(settingsSource.contains("isOnlyEnabled"))
        XCTAssertTrue(settingsSource.contains("Picker(\"날짜 기준\""))
        XCTAssertTrue(settingsSource.contains("UsageGraphDateBaseline.allCases"))
        let dateBaselineSource = try String(contentsOfFile: "Sources/MacDog/UsageGraphDateBaseline.swift")
        let petMenuSource = try String(contentsOfFile: "Sources/MacDog/PetMenuModel.swift")
        let sleepPanelSource = try String(contentsOfFile: "Sources/MacDog/Popover/SleepPreventionPanel.swift")
        XCTAssertTrue(dateBaselineSource.contains("return \"자정\""))
        XCTAssertTrue(petMenuSource.contains("usageProviderMode.petTitle"))
        XCTAssertFalse(petMenuSource.contains("코덱스 펫"))
        XCTAssertTrue(sleepPanelSource.contains("runningTriggerTitle"))
        XCTAssertTrue(settingsSource.contains("UsageProviderMode.visibleCases"))
        XCTAssertFalse(settingsSource.contains("UsageProviderMode.allCases"))
        XCTAssertFalse(settingsSource.contains("Claude Usage Preview"))
        XCTAssertFalse(settingsSource.contains("Claude Preview 사용"))
        XCTAssertFalse(settingsSource.contains("러너 반영"))
        XCTAssertFalse(settingsSource.contains("Claude 알림"))
        XCTAssertFalse(popoverSource.contains("Picker(\"사용량 provider\""))
        XCTAssertTrue(popoverSource.contains("state.usageProviderMode == .claude")
            || popoverSource.contains("state.runtimeProviderMode == .claude"))
        XCTAssertTrue(popoverSource.contains("statusTitle(now: now)"))
        XCTAssertTrue(popoverSource.contains("ClaudeUsagePreviewPanel(preview: state.claudeUsagePreview, now: now)"))
        XCTAssertFalse(claudePanelSource.contains("live 구독 검수 미수행"))
        XCTAssertTrue(controllerSource.contains("switch UsageNotificationRoute(mode: loadedState.usageProviderMode)"))
        XCTAssertTrue(controllerSource.contains("usageProviderSelection: preferences.usageProviderSelection"))
        XCTAssertTrue(controllerSource.contains("NSStatusItem.variableLength"))
        XCTAssertTrue(controllerSource.contains("MenuBarWeeklyRemainingLabel.make("))
        XCTAssertTrue(controllerSource.contains("button.imagePosition = .imageLeading"))
        XCTAssertTrue(popoverSource.contains("GrokUsagePanel("))
        XCTAssertTrue(popoverSource.contains("preview: state.grokUsage"))
        XCTAssertTrue(popoverSource.contains("showsWeeklyGraph:"))
        XCTAssertTrue(popoverSource.contains("CombinedUsageGaugesView("))
        XCTAssertTrue(popoverSource.contains("pinsCombinedUsageGauges"))
        XCTAssertTrue(popoverSource.contains("selectedModule == .codex"))
        XCTAssertTrue(popoverSource.contains("fixedSize(horizontal: false, vertical: true)"))
        let gaugesSource = try String(contentsOfFile: "Sources/MacDog/CombinedUsageGauges.swift")
        XCTAssertTrue(gaugesSource.contains("gauges.groups"))
        XCTAssertTrue(gaugesSource.contains("RemainingUsageBar("))
        XCTAssertTrue(gaugesSource.contains("group.provider.label"))
        let codexPanelSourceForOrder = try String(contentsOfFile: "Sources/MacDog/Popover/CodexUsagePanel.swift")
        let graphRange = try XCTUnwrap(codexPanelSourceForOrder.range(of: "WeeklyRemainingHistoryBlock("))
        let creditsRange = try XCTUnwrap(codexPanelSourceForOrder.range(of: "CodexResetCreditsBlock("))
        XCTAssertLessThan(graphRange.lowerBound, creditsRange.lowerBound)
        XCTAssertTrue(codexPanelSourceForOrder.contains("fiveHourIsAvailable: false"))
        let codexPanelSource = try String(contentsOfFile: "Sources/MacDog/Popover/CodexUsagePanel.swift")
        XCTAssertTrue(codexPanelSource.contains("showsMainWeeklyGraph"))
        XCTAssertTrue(codexPanelSource.contains("CodexWeeklyPacemakerBlock("))
        XCTAssertTrue(codexPanelSource.contains("CodexResetCreditsBlock("))
        XCTAssertFalse(popoverSource.contains("Picker(\"사용량 provider\""))
        XCTAssertFalse(popoverSource.contains(".pickerStyle(.segmented)"))
        XCTAssertFalse(grokPanelSource.contains("5시간"))
        XCTAssertTrue(grokPanelSource.contains("주간"))
        XCTAssertTrue(grokPanelSource.contains("WeeklyRemainingHistoryBlock("))
        XCTAssertFalse(grokPanelSource.contains("GrokUsageGraphSnapshotView"))
        XCTAssertTrue(grokPanelSource.contains("grok login"))
        XCTAssertTrue(grokPanelSource.contains("터미널에서 로그인"))
        XCTAssertTrue(grokPanelSource.contains("로그인 명령 복사"))
        XCTAssertFalse(grokPanelSource.contains("초기화권"))
        XCTAssertFalse(grokPanelSource.contains("reset credit"))
        XCTAssertTrue(controllerSource.contains("grokUsageNotificationDispatcher.dispatch"))
        XCTAssertTrue(controllerSource.contains("UsageProviderWorkDiff.make"))
        XCTAssertFalse(controllerSource.contains("cancelProviderBoundWork(for:"))
    }

    func testCodexUsagePanelKeepsSixResetCreditsVisibleWithoutDisclosure() throws {
        let state = UsageMonitorState(
            report: Self.codexReportWithResetCredits(Self.resetCredits(count: 6, shuffled: true)),
            cacheSnapshot: nil,
            weeklyUsageHistory: .empty,
            resetWindowHistory: .empty,
            errorMessage: nil,
            systemMetrics: .unavailable
        )
        let view = CodexUsagePanel(state: state)

        let contentWidth = MacDogPopoverLayout.contentSurfaceSize.width -
            (MacDogPopoverLayout.contentPadding * 2)
        let contentHeight = MacDogPopoverLayout.nonScrollableContentHeight
        let hostingView = NSHostingView(rootView: view.frame(width: contentWidth))
        hostingView.frame = NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
        hostingView.layoutSubtreeIfNeeded()

        XCTAssertLessThanOrEqual(hostingView.fittingSize.height, contentHeight)
    }

    func testWeeklyHistoryBlockExposesModePickerAndWiresGraphActions() throws {
        let report = Self.codexReportWithThreeResetCreditExpiries()
        let weeklyWindow = try XCTUnwrap(report.limits["codex"]?.secondary)
        let currentReset = try XCTUnwrap(weeklyWindow.resetsAt)
        let pastReset = currentReset - 604_800
        let history = CodexUsageResetWindowHistory(records: [
            CodexUsageResetWindowHistoryRecord(
                generatedAt: pastReset - 60,
                limitId: "codex",
                windowDurationMins: 10_080,
                resetsAt: pastReset,
                dailyEndSamples: [
                    CodexUsageResetWindowDailySample(
                        dayIndex: 7,
                        recordedAt: pastReset - 60,
                        usedPercent: 72,
                        remainingPercent: 28
                    )
                ],
                finalUsedPercent: 72,
                finalRemainingPercent: 28,
                sampleCount: 1,
                source: .backfill
            )
        ])
        let view = WeeklyRemainingHistoryBlock(
            history: .empty,
            resetWindowHistory: history,
            weeklyWindow: weeklyWindow,
            currentReport: report,
            currentTimestamp: report.generatedAt
        )

        let hostingView = NSHostingView(rootView: view.frame(width: 292))
        hostingView.frame = NSRect(x: 0, y: 0, width: 292, height: 140)
        hostingView.layoutSubtreeIfNeeded()

        let descendants = allDescendants(of: hostingView)
        XCTAssertFalse(
            descendants.contains { $0 is NSSegmentedControl },
            "history mode tabs should avoid the default segmented control chrome"
        )
        XCTAssertEqual(modeTabButtons(in: hostingView).map(\.title), ["현재", "지난", "비교"])
        let source = try String(contentsOfFile: "Sources/MacDog/Popover/WeeklyRemainingHistoryViews.swift")
        XCTAssertTrue(source.contains("graphActionButtons(mode: mode"))
    }

    func testWeeklyHistoryCurrentModeUsesCompactModeControlWithoutWindowPicker() throws {
        let view = try weeklyHistoryBlock(initialMode: .current)
        let hostingView = NSHostingView(rootView: view.frame(width: 292))
        hostingView.frame = NSRect(x: 0, y: 0, width: 292, height: 140)
        hostingView.layoutSubtreeIfNeeded()

        let descendants = allDescendants(of: hostingView)
        let modeTabs = modeTabButtons(in: hostingView)

        XCTAssertEqual(modeTabs.map(\.title), ["현재", "지난", "비교"])
        XCTAssertLessThanOrEqual(modeTabFrame(for: modeTabs, in: hostingView).width, 86)
        XCTAssertFalse(
            descendants.contains { $0 is NSPopUpButton },
            "current mode should not show the past-window dropdown"
        )
    }

    func testWeeklyHistoryPastModeKeepsCompactModeControlAndShowsWindowPicker() throws {
        let view = try weeklyHistoryBlock(initialMode: .past)
        let hostingView = NSHostingView(rootView: view.frame(width: 292))
        hostingView.frame = NSRect(x: 0, y: 0, width: 292, height: 140)
        hostingView.layoutSubtreeIfNeeded()

        let descendants = allDescendants(of: hostingView)
        let modeTabs = modeTabButtons(in: hostingView)
        let windowPicker = try XCTUnwrap(descendants.compactMap { $0 as? NSPopUpButton }.first)
        let modeTabFrame = modeTabFrame(for: modeTabs, in: hostingView)
        let windowPickerFrame = windowPicker.convert(windowPicker.bounds, to: hostingView)

        XCTAssertEqual(modeTabs.map(\.title), ["현재", "지난", "비교"])
        XCTAssertLessThanOrEqual(modeTabFrame.width, 86)
        XCTAssertGreaterThanOrEqual(windowPickerFrame.minX - modeTabFrame.maxX, 24)
        XCTAssertEqual(windowPickerFrame.maxX, hostingView.bounds.maxX, accuracy: 1)
    }

    func testWeeklyHistoryWindowPickerUsesActualEndDatesForInterruptedWindows() throws {
        let calendar = Calendar.current
        let olderStart = Int(try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 7,
            hour: 9
        ))).timeIntervalSince1970.rounded())
        let newerStart = olderStart + 3 * 60 * 60
        let currentStart = olderStart + 23 * 60 * 60
        let durationSeconds = 10_080 * 60
        let records = [olderStart, newerStart].map { start in
            CodexUsageResetWindowHistoryRecord(
                generatedAt: start + 60,
                limitId: "codex",
                windowDurationMins: 10_080,
                resetsAt: start + durationSeconds,
                dailyEndSamples: [],
                finalUsedPercent: 1,
                finalRemainingPercent: 99,
                sampleCount: 1,
                source: .backfill
            )
        }
        let weeklyWindow = UsageWindowReport(
            kind: .weekly,
            usedPercent: 1,
            remainingPercent: 99,
            windowDurationMins: 10_080,
            resetsAt: currentStart + durationSeconds
        )
        let view = WeeklyRemainingHistoryBlock(
            history: .empty,
            resetWindowHistory: CodexUsageResetWindowHistory(records: records),
            weeklyWindow: weeklyWindow,
            currentReport: nil,
            currentTimestamp: currentStart + 60,
            initialMode: .past
        )
        let hostingView = NSHostingView(rootView: view.frame(width: 292))
        hostingView.frame = NSRect(x: 0, y: 0, width: 292, height: 140)
        hostingView.layoutSubtreeIfNeeded()

        let picker = try XCTUnwrap(
            allDescendants(of: hostingView).compactMap { $0 as? NSPopUpButton }.first
        )
        let itemTitles = (0..<picker.numberOfItems).map { picker.itemTitle(at: $0) }

        XCTAssertEqual(itemTitles, ["7/7-7/8", "7/7-7/7"])
        XCTAssertEqual(Set(itemTitles).count, itemTitles.count)
    }

    func testWeeklyHistoryModeSwitchingDoesNotCrashAndCurrentHidesWindowPicker() throws {
        let view = try weeklyHistoryBlock(initialMode: .current)
        let hostingView = NSHostingView(rootView: view.frame(width: 292))
        hostingView.frame = NSRect(x: 0, y: 0, width: 292, height: 140)
        hostingView.layoutSubtreeIfNeeded()

        var descendants = allDescendants(of: hostingView)
        var modeTabs = modeTabButtons(in: hostingView)
        XCTAssertEqual(modeTabs.map(\.title), ["현재", "지난", "비교"])

        modeTabs[1].performClick(nil)
        hostingView.layoutSubtreeIfNeeded()
        descendants = allDescendants(of: hostingView)
        XCTAssertTrue(descendants.contains { $0 is NSPopUpButton })

        modeTabs = modeTabButtons(in: hostingView)
        modeTabs[2].performClick(nil)
        hostingView.layoutSubtreeIfNeeded()
        descendants = allDescendants(of: hostingView)
        XCTAssertTrue(descendants.contains { $0 is NSPopUpButton })

        modeTabs = modeTabButtons(in: hostingView)
        modeTabs[0].performClick(nil)
        hostingView.layoutSubtreeIfNeeded()
        descendants = allDescendants(of: hostingView)
        XCTAssertFalse(descendants.contains { $0 is NSPopUpButton })
    }

    func testWeeklyHistoryModeTabsDoNotExpandIntoBlankVerticalSpace() throws {
        let view = try weeklyHistoryBlock(initialMode: .current)
        let hostingView = NSHostingView(rootView: view.frame(width: 292))
        hostingView.frame = NSRect(x: 0, y: 0, width: 292, height: 140)
        hostingView.layoutSubtreeIfNeeded()

        let modeTabs = modeTabButtons(in: hostingView)
        XCTAssertEqual(modeTabs.map(\.title), ["현재", "지난", "비교"])

        let stack = try XCTUnwrap(modeTabs.first?.superview as? NSStackView)
        XCTAssertEqual(stack.frame.height, 16, accuracy: 0.5)
    }

    func testWeeklyHistoryModeSwitchingKeepsFiveWindowPickerSelectionValid() throws {
        let view = try weeklyHistoryBlock(initialMode: .current, pastWindowCount: 5)
        let hostingView = NSHostingView(rootView: view.frame(width: 292))
        hostingView.frame = NSRect(x: 0, y: 0, width: 292, height: 140)
        hostingView.layoutSubtreeIfNeeded()

        for selectedTitle in ["지난", "비교", "현재", "지난", "비교"] {
            let modeButton = try XCTUnwrap(
                modeTabButtons(in: hostingView).first { $0.title == selectedTitle }
            )
            modeButton.performClick(nil)
            hostingView.layoutSubtreeIfNeeded()

            let windowPickers = allDescendants(of: hostingView).compactMap { $0 as? NSPopUpButton }
            if selectedTitle == "현재" {
                XCTAssertTrue(windowPickers.isEmpty)
            } else {
                let picker = try XCTUnwrap(windowPickers.first)
                XCTAssertEqual(picker.numberOfItems, 5)
                XCTAssertTrue((0..<picker.numberOfItems).contains(picker.indexOfSelectedItem))
            }
        }
    }

    func testRenderReadmeScreenshotsWhenRequested() throws {
        guard ProcessInfo.processInfo.environment["MACDOG_RENDER_README_SCREENSHOTS"] == "1" else {
            throw XCTSkip("README screenshot rendering is opt-in.")
        }

        let outputRoot = ProcessInfo.processInfo.environment["MACDOG_RENDER_README_SCREENSHOTS_OUTPUT_DIR"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Assets", isDirectory: true)
                .appendingPathComponent("Generated", isDirectory: true)
                .appendingPathComponent("Docs", isDirectory: true)
        let outputDirectory = outputRoot.appendingPathComponent("PopoverTabs", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let defaults = UserDefaults.standard
        let keysToRestore = [
            RunnerPreferences.popoverModuleKey,
            RunnerPreferences.sleepPreventionControlModeKey,
            RunnerPreferences.sleepPreventionEnabledKey,
            RunnerPreferences.sleepPreventionSessionPresetKey,
            RunnerPreferences.sleepPreventionEndsAtKey,
            RunnerPreferences.sleepPreventionPowerAdapterTriggerKey,
            RunnerPreferences.sleepPreventionCodexAppTriggerKey,
            RunnerPreferences.sleepPreventionChargingBelowThresholdTriggerKey,
            RunnerPreferences.sleepPreventionCPUThresholdTriggerKey,
            RunnerPreferences.sleepPreventionMemoryThresholdTriggerKey,
            RunnerPreferences.sleepPreventionNetworkActivityTriggerKey,
            RunnerPreferences.sleepPreventionExternalVolumeTriggerKey,
            RunnerPreferences.sleepPreventionBatteryThresholdPercentKey,
            RunnerPreferences.sleepPreventionCPUThresholdPercentKey,
            RunnerPreferences.sleepPreventionMemoryThresholdPercentKey,
            RunnerPreferences.sleepPreventionNetworkThresholdKBPerSecondKey,
            RunnerPreferences.sleepPreventionAppMatchTextKey,
            RunnerPreferences.sleepPreventionPreventDisplaySleepKey,
            RunnerPreferences.sleepPreventionPreventClosedLidSleepKey,
            RunnerPreferences.sleepPreventionDisableScreenLockKey,
            RunnerPreferences.chargeLimitTargetPercentKey,
            RunnerPreferences.loginLaunchEnabledKey,
            RunnerPreferences.usageNotificationsEnabledKey,
            RunnerPreferences.usageResetSoonNotificationsEnabledKey,
            RunnerPreferences.usageProviderModeKey,
            RunnerPreferences.usageEnabledProviderMaskKey,
            RunnerPreferences.usageDetailGraphVisibleKey,
            RunnerPreferences.usageGraphDateBaselineKey
        ]
        var previousValues: [String: Any] = [:]
        for key in keysToRestore {
            previousValues[key] = defaults.object(forKey: key)
        }

        defer {
            for key in keysToRestore {
                if let value = previousValues[key] {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }

        let requestedModules = Set(
            ProcessInfo.processInfo.environment["MACDOG_RENDER_README_SCREENSHOTS_MODULES"]?
                .split(separator: ",")
                .map { String($0) } ?? []
        )
        let screenshotNow = Date(timeIntervalSince1970: TimeInterval(MacDogDemoData.readmeScreenshotTimestamp))
        for module in MacDogPopoverModule.allCases where
            requestedModules.isEmpty || requestedModules.contains(module.rawValue) {
            configureDefaults(for: module, defaults: defaults)
            let preferences = RunnerPreferences(defaults: defaults)
            let state = MacDogDemoData.state(
                preferences: preferences,
                now: MacDogDemoData.readmeScreenshotTimestamp
            )
            let view = UsagePopoverView(
                state: state,
                notificationAuthorizationClient: StaticUsageNotificationAuthorizationClient(status: .notDetermined),
                now: screenshotNow
            )
            let image = render(view: view, size: NSSize(width: 370, height: 408), scale: 2)
            try write(image: image, to: outputDirectory.appendingPathComponent("macdog-popover-\(module.rawValue).png"))
        }

        if requestedModules.isEmpty || requestedModules.contains("grok") {
            configureDefaults(for: .codex, defaults: defaults)
            RunnerPreferences.setUsageProviderMode(.grok, defaults: defaults)
            let preferences = RunnerPreferences(defaults: defaults)
            let state = MacDogDemoData.state(
                preferences: preferences,
                now: MacDogDemoData.readmeScreenshotTimestamp
            )
            let view = UsagePopoverView(
                state: state,
                notificationAuthorizationClient: StaticUsageNotificationAuthorizationClient(status: .notDetermined),
                now: screenshotNow
            )
            let image = render(view: view, size: NSSize(width: 370, height: 408), scale: 2)
            try write(image: image, to: outputDirectory.appendingPathComponent("macdog-popover-grok.png"))
        }

        let petSource = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent("MacDog", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("DesktopPet", isDirectory: true)
            .appendingPathComponent("pup-idle-front-0.png")
        let petDestination = outputRoot.appendingPathComponent("macdog-desktop-pet-front.png")
        if FileManager.default.fileExists(atPath: petDestination.path) {
            try FileManager.default.removeItem(at: petDestination)
        }
        try FileManager.default.copyItem(at: petSource, to: petDestination)
    }

    func testRenderLiveCodexPopoverScreenshotWhenRequested() throws {
        guard ProcessInfo.processInfo.environment["MACDOG_RENDER_LIVE_CODEX_POPOVER"] == "1" else {
            throw XCTSkip("Live Codex popover rendering is opt-in.")
        }

        let outputDirectory = ProcessInfo.processInfo.environment["MACDOG_RENDER_LIVE_CODEX_POPOVER_OUTPUT_DIR"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent("macdog-live-popover", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let cacheSnapshot = try CodexUsageCacheStore().read()
        let weeklyHistory = try ProcessInfo.processInfo.environment["MACDOG_LIVE_WEEKLY_HISTORY_PATH"]
            .map {
                try JSONDecoder().decode(
                    CodexUsageWeeklyHistory.self,
                    from: Data(contentsOf: URL(fileURLWithPath: $0))
                )
            } ?? ((try? CodexUsageWeeklyHistoryStore().read()) ?? .empty)
        let resetWindowHistory = try ProcessInfo.processInfo.environment["MACDOG_LIVE_RESET_HISTORY_PATH"]
            .map {
                try JSONDecoder().decode(
                    CodexUsageResetWindowHistory.self,
                    from: Data(contentsOf: URL(fileURLWithPath: $0))
                )
            } ?? ((try? CodexUsageResetWindowHistoryStore().read()) ?? .empty)
        guard let report = cacheSnapshot.report else {
            XCTFail("Live cache snapshot has no usage report.")
            return
        }

        let defaults = UserDefaults.standard
        let previousModule = defaults.object(forKey: RunnerPreferences.popoverModuleKey)
        defer {
            if let previousModule {
                defaults.set(previousModule, forKey: RunnerPreferences.popoverModuleKey)
            } else {
                defaults.removeObject(forKey: RunnerPreferences.popoverModuleKey)
            }
        }
        defaults.set(MacDogPopoverModule.codex.rawValue, forKey: RunnerPreferences.popoverModuleKey)

        let state = UsageMonitorState(
            report: report,
            cacheSnapshot: cacheSnapshot,
            weeklyUsageHistory: weeklyHistory,
            resetWindowHistory: resetWindowHistory,
            errorMessage: cacheSnapshot.error?.message,
            systemMetrics: .unavailable
        )
        let view = UsagePopoverView(
            state: state,
            notificationAuthorizationClient: StaticUsageNotificationAuthorizationClient(status: .notDetermined)
        )
        let image = render(view: view, size: NSSize(width: 370, height: 408), scale: 2)
        try write(image: image, to: outputDirectory.appendingPathComponent("macdog-popover-live-codex.png"))

        if let comparisonModel = CodexUsageHistoryComparisonModel(state: state) {
            let labels = comparisonModel.pastWindows.map {
                CodexUsageHistoryTimelineLabel.windowLabel(
                    for: $0,
                    endingAt: comparisonModel.displayEndAt(for: $0)
                )
            }
            XCTAssertEqual(Set(labels).count, labels.count)
            print("Live Codex history windows: \(labels.joined(separator: ", "))")

            let historyView = WeeklyRemainingHistoryBlock(
                history: weeklyHistory,
                resetWindowHistory: resetWindowHistory,
                weeklyWindow: report.limits["codex"]?.secondary,
                currentReport: report,
                currentTimestamp: cacheSnapshot.cachedAt,
                initialMode: .past
            )
            let historyImage = render(view: historyView, size: NSSize(width: 292, height: 140), scale: 2)
            try write(
                image: historyImage,
                to: outputDirectory.appendingPathComponent("macdog-live-codex-history-past.png")
            )
        }
    }

    func testRenderReadmeCodexComparisonScreenshotWhenRequested() throws {
        guard ProcessInfo.processInfo.environment["MACDOG_RENDER_README_CODEX_COMPARISON"] == "1" else {
            throw XCTSkip("README Codex comparison rendering is opt-in.")
        }

        let outputDirectory = ProcessInfo.processInfo.environment["MACDOG_RENDER_README_CODEX_COMPARISON_OUTPUT_DIR"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent("macdog-readme-codex-comparison", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let defaults = UserDefaults.standard
        let previousModule = defaults.object(forKey: RunnerPreferences.popoverModuleKey)
        defer {
            if let previousModule {
                defaults.set(previousModule, forKey: RunnerPreferences.popoverModuleKey)
            } else {
                defaults.removeObject(forKey: RunnerPreferences.popoverModuleKey)
            }
        }
        defaults.set(MacDogPopoverModule.codex.rawValue, forKey: RunnerPreferences.popoverModuleKey)

        let preferences = RunnerPreferences(defaults: defaults)
        let state = MacDogDemoData.state(
            preferences: preferences,
            now: MacDogDemoData.readmeScreenshotTimestamp
        )
        let view = UsagePopoverView(
            state: state,
            notificationAuthorizationClient: StaticUsageNotificationAuthorizationClient(status: .notDetermined)
        )
        let hostingView = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor)))
        hostingView.appearance = NSAppearance(named: .darkAqua)
        hostingView.frame = NSRect(origin: .zero, size: NSSize(width: 370, height: 408))
        hostingView.setFrameSize(NSSize(width: 370, height: 408))
        hostingView.layoutSubtreeIfNeeded()

        let comparisonButton = try XCTUnwrap(
            allDescendants(of: hostingView)
                .compactMap { $0 as? NSButton }
                .first { $0.title == "비교" }
        )
        comparisonButton.performClick(nil)
        hostingView.layoutSubtreeIfNeeded()

        let image = snapshot(hostingView: hostingView, size: NSSize(width: 370, height: 408), scale: 2)
        try write(image: image, to: outputDirectory.appendingPathComponent("macdog-popover-codex-comparison.png"))
    }

    private func configureDefaults(for module: MacDogPopoverModule, defaults: UserDefaults) {
        RunnerPreferences.setSleepPreventionControlMode(.off, defaults: defaults)
        RunnerPreferences.setUsageProviderMode(.codex, defaults: defaults)
        RunnerPreferences.setUsageGraphDateBaseline(.calendarMidnight, defaults: defaults)
        defaults.set(module.rawValue, forKey: RunnerPreferences.popoverModuleKey)

        if module == .sleep {
            RunnerPreferences.setSleepPreventionControlMode(.condition, defaults: defaults)
            RunnerPreferences.setSleepPreventionPowerAdapterTrigger(true, defaults: defaults)
            RunnerPreferences.setSleepPreventionCodexAppTrigger(true, defaults: defaults)
            RunnerPreferences.setSleepPreventionChargingBelowThresholdTrigger(true, defaults: defaults)
            RunnerPreferences.setSleepPreventionMemoryThresholdTrigger(true, defaults: defaults)
            RunnerPreferences.setSleepPreventionNetworkActivityTrigger(true, defaults: defaults)
            RunnerPreferences.setSleepPreventionBatteryThresholdPercent(
                RunnerPreferences.defaultSleepPreventionBatteryThresholdPercent,
                defaults: defaults
            )
            RunnerPreferences.setSleepPreventionCPUThresholdPercent(
                RunnerPreferences.defaultSleepPreventionCPUThresholdPercent,
                defaults: defaults
            )
            RunnerPreferences.setSleepPreventionMemoryThresholdPercent(
                RunnerPreferences.defaultSleepPreventionMemoryThresholdPercent,
                defaults: defaults
            )
            RunnerPreferences.setSleepPreventionNetworkThresholdKBPerSecond(256, defaults: defaults)
            RunnerPreferences.setSleepPreventionAppMatchText("Codex", defaults: defaults)
        }

        if module == .settings {
            RunnerPreferences.setDesktopPetEnabled(true, defaults: defaults)
            RunnerPreferences.setReducedMotion(false, defaults: defaults)
            RunnerPreferences.setAnimationPaused(false, defaults: defaults)
            RunnerPreferences.setLoginLaunchEnabled(true, defaults: defaults)
            RunnerPreferences.setUsageNotificationsEnabled(false, defaults: defaults)
            RunnerPreferences.setUsageResetSoonNotificationsEnabled(true, defaults: defaults)
            RunnerPreferences.setUsageMenuBarWeeklyRemainingVisible(true, defaults: defaults)
        }

        if module == .battery {
            RunnerPreferences.setChargeLimitTargetPercent(90, defaults: defaults)
        }
    }

    private static func codexReportWithThreeResetCreditExpiries() -> CodexUsageReport {
        codexReportWithResetCredits(resetCredits(count: 3, shuffled: false))
    }

    private static func claudePreview(
        now: Date,
        observedAtOffset: Int = 0,
        staleAfterSeconds: Int = 900,
        includeSevenDay: Bool = true,
        issueCode: String? = nil
    ) -> ClaudeUsagePreviewState {
        let nowTimestamp = Int(now.timeIntervalSince1970)
        let observedAt = nowTimestamp + observedAtOffset
        let fiveHourReset = nowTimestamp + 10_000
        let sevenDayReset = nowTimestamp + 500_000
        let usage = ClaudeStatusLineSnapshot(
            observedAt: observedAt,
            fiveHour: try! ClaudeUsageWindowSnapshot(usedPercent: 44, resetsAt: fiveHourReset),
            sevenDay: includeSevenDay
                ? try! ClaudeUsageWindowSnapshot(usedPercent: 67, resetsAt: sevenDayReset)
                : nil
        )
        let pastReset = sevenDayReset - ClaudeUsageWindowKind.sevenDay.windowDurationMins * 60
        let history = ClaudeUsageHistory(samples: [
            ClaudeUsageHistorySample(
                kind: .fiveHour,
                recordedAt: observedAt,
                usedPercent: 44,
                resetsAt: fiveHourReset
            )!,
            ClaudeUsageHistorySample(
                kind: .sevenDay,
                recordedAt: observedAt - 20_000,
                usedPercent: 55,
                resetsAt: sevenDayReset
            )!,
            ClaudeUsageHistorySample(
                kind: .sevenDay,
                recordedAt: observedAt,
                usedPercent: 67,
                resetsAt: sevenDayReset
            )!,
            ClaudeUsageHistorySample(
                kind: .sevenDay,
                recordedAt: pastReset - 40_000,
                usedPercent: 72,
                resetsAt: pastReset
            )!
        ])
        return ClaudeUsagePreviewState(
            isEnabled: true,
            cacheSnapshot: ClaudeUsageCacheSnapshot(
                lastEventAt: observedAt,
                lastUsageObservedAt: observedAt,
                staleAfterSeconds: staleAfterSeconds,
                usage: usage,
                issue: issueCode.map { ClaudeUsageCacheIssue(code: $0, recordedAt: observedAt) }
            ),
            history: history,
            loadIssue: nil
        )
    }

    private func weeklyHistoryBlock(
        initialMode: CodexUsageHistoryGraphMode,
        pastWindowCount: Int = 1
    ) throws -> WeeklyRemainingHistoryBlock {
        let report = Self.codexReportWithThreeResetCreditExpiries()
        let weeklyWindow = try XCTUnwrap(report.limits["codex"]?.secondary)
        let currentReset = try XCTUnwrap(weeklyWindow.resetsAt)
        let records = (1...pastWindowCount).map { offset in
            let pastReset = currentReset - offset * 604_800
            return CodexUsageResetWindowHistoryRecord(
                generatedAt: pastReset - 60,
                limitId: "codex",
                windowDurationMins: 10_080,
                resetsAt: pastReset,
                dailyEndSamples: [
                    CodexUsageResetWindowDailySample(
                        dayIndex: 7,
                        recordedAt: pastReset - 60,
                        usedPercent: 72,
                        remainingPercent: 28
                    )
                ],
                finalUsedPercent: 72,
                finalRemainingPercent: 28,
                sampleCount: 1,
                source: .backfill
            )
        }
        let history = CodexUsageResetWindowHistory(records: records)
        return WeeklyRemainingHistoryBlock(
            history: .empty,
            resetWindowHistory: history,
            weeklyWindow: weeklyWindow,
            currentReport: report,
            currentTimestamp: report.generatedAt,
            initialMode: initialMode
        )
    }

    private static func codexReportWithResetCredits(_ resetCredits: RateLimitResetCreditsSummary) -> CodexUsageReport {
        CodexUsageReport(
            generatedAt: 1_800_000_000,
            source: "test",
            planType: "pro",
            credits: nil,
            resetCredits: resetCredits,
            rateLimitReachedType: nil,
            limits: [
                "codex": UsageLimitReport(
                    limitId: "codex",
                    limitName: "Codex",
                    primary: UsageWindowReport(
                        kind: .fiveHour,
                        usedPercent: 6,
                        remainingPercent: 94,
                        windowDurationMins: 300,
                        resetsAt: 1_800_015_600
                    ),
                    secondary: UsageWindowReport(
                        kind: .weekly,
                        usedPercent: 67,
                        remainingPercent: 33,
                        windowDurationMins: 10_080,
                        resetsAt: 1_800_056_400
                    ),
                    credits: nil,
                    planType: "pro",
                    rateLimitReachedType: nil
                )
            ]
        )
    }

    private static func weeklyOnlyCodexReport() -> CodexUsageReport {
        CodexUsageReport(
            generatedAt: 1_800_000_000,
            source: "test",
            planType: "pro",
            credits: nil,
            rateLimitReachedType: nil,
            limits: [
                "codex": UsageLimitReport(
                    limitId: "codex",
                    limitName: "Codex",
                    primary: UsageWindowReport(
                        kind: .weekly,
                        usedPercent: 67,
                        remainingPercent: 33,
                        windowDurationMins: 10_080,
                        resetsAt: 1_800_056_400
                    ),
                    secondary: nil,
                    credits: nil,
                    planType: "pro",
                    rateLimitReachedType: nil
                )
            ]
        )
    }

    private static func resetCredits(count: Int, shuffled: Bool) -> RateLimitResetCreditsSummary {
        let expiries = [
            "2026-07-18T00:34:01.707337Z",
            "2026-07-26T23:47:07.735255Z",
            "2026-07-31T19:07:22.221365Z",
            "2026-08-05T03:20:00Z",
            "2026-08-09T12:10:00Z",
            "2026-08-12T14:45:00Z"
        ]
        var credits = Array(expiries.prefix(count)).enumerated().map { index, expiry in
            RateLimitResetCredit(
                id: "credit_\(index + 1)",
                status: "available",
                resetType: "manual",
                expiresAt: expiry
            )
        }

        if shuffled {
            credits = Array(credits.reversed())
        }

        return RateLimitResetCreditsSummary(
            availableCount: count,
            credits: credits
        )
    }

    private func renderUsagePopover(_ state: UsageMonitorState) -> NSImage {
        let view = UsagePopoverView(
            state: state,
            notificationAuthorizationClient: StaticUsageNotificationAuthorizationClient(status: .notDetermined)
        )
        return render(view: view, size: NSSize(width: 370, height: 408), scale: 2)
    }

    private func render<V: View>(view: V, size: NSSize, scale: CGFloat) -> NSImage {
        let hostingView = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor)))
        hostingView.appearance = NSAppearance(named: .darkAqua)
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.setFrameSize(size)
        hostingView.layoutSubtreeIfNeeded()
        _ = snapshot(hostingView: hostingView, size: size, scale: scale)
        hostingView.needsLayout = true
        hostingView.layoutSubtreeIfNeeded()
        hostingView.displayIfNeeded()

        return snapshot(hostingView: hostingView, size: size, scale: scale)
    }

    private func screenshotColorDistance(
        in image: NSImage,
        from firstPoint: CGPoint,
        to secondPoint: CGPoint
    ) -> Double {
        guard
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff)
        else {
            return 0
        }
        guard
            let first = bitmap.colorAt(
                x: Int(Double(bitmap.pixelsWide - 1) * firstPoint.x),
                y: Int(Double(bitmap.pixelsHigh - 1) * firstPoint.y)
            )?.usingColorSpace(.deviceRGB),
            let second = bitmap.colorAt(
                x: Int(Double(bitmap.pixelsWide - 1) * secondPoint.x),
                y: Int(Double(bitmap.pixelsHigh - 1) * secondPoint.y)
            )?.usingColorSpace(.deviceRGB)
        else {
            return 0
        }
        let red = first.redComponent - second.redComponent
        let green = first.greenComponent - second.greenComponent
        let blue = first.blueComponent - second.blueComponent
        return sqrt((red * red) + (green * green) + (blue * blue))
    }

    private func snapshot(hostingView: NSView, size: NSSize, scale: CGFloat) -> NSImage {
        let pixelWidth = Int(size.width * scale)
        let pixelHeight = Int(size.height * scale)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            fatalError("Failed to allocate screenshot bitmap")
        }
        bitmap.size = size

        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)

        let image = NSImage(size: size)
        image.addRepresentation(bitmap)
        return image
    }

    private func write(image: NSImage, to url: URL) throws {
        guard
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let png = bitmap.representation(using: .png, properties: [:])
        else {
            XCTFail("Failed to encode screenshot at \(url.path)")
            return
        }

        try png.write(to: url)
    }

    private func allDescendants(of view: NSView) -> [NSView] {
        view.subviews + view.subviews.flatMap(allDescendants)
    }

    private func modeTabButtons(in view: NSView) -> [NSButton] {
        let modeTitles = Set(["현재", "지난", "비교"])
        return allDescendants(of: view)
            .compactMap { $0 as? NSButton }
            .filter { modeTitles.contains($0.title) }
            .sorted { first, second in
                first.convert(first.bounds, to: view).minX < second.convert(second.bounds, to: view).minX
            }
    }

    private func modeTabFrame(for buttons: [NSButton], in view: NSView) -> NSRect {
        buttons
            .map { $0.convert($0.bounds, to: view) }
            .reduce(.null) { $0.union($1) }
    }
}
