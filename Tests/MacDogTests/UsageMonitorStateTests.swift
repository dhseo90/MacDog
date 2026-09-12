import XCTest
import CodexUsageCore
import MacDogPrivilegedHelperSupport
@testable import MacDog

final class UsageMonitorStateTests: XCTestCase {
    func testUsagePressurePhaseThresholds() {
        XCTAssertEqual(UsagePressurePhase(usedPercent: 49.9), .calm)
        XCTAssertEqual(UsagePressurePhase(usedPercent: 50), .active)
        XCTAssertEqual(UsagePressurePhase(usedPercent: 80), .fast)
        XCTAssertEqual(UsagePressurePhase(usedPercent: 95), .sprint)
        XCTAssertEqual(UsagePressurePhase(usedPercent: 100), .limit)
    }

    func testUsagePressurePhaseThresholdSummaryMatchesPopoverLegend() {
        XCTAssertEqual(UsagePressurePhase.thresholdSummary, "50% 활발 · 80% 빠름 · 95% 질주")
    }

    func testWeeklyRemainingEighteenPercentMakesRunnerFast() {
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 0, weeklyUsedPercent: 82),
            cacheSnapshot: nil,
            errorMessage: nil,
            displayBasis: .weekly
        )

        XCTAssertEqual(state.selectedUsedPercent, 82)
        XCTAssertEqual(state.selectedWindowStatus?.remainingSummary, "주간 18% 남음")
        XCTAssertEqual(state.phase, .fast)
        XCTAssertEqual(state.phase.frameInterval, 0.18)
    }

    func testMaxBasisUsesHigherCodexUsageWindowForRunnerPhase() {
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 24, weeklyUsedPercent: 82),
            cacheSnapshot: nil,
            errorMessage: nil,
            displayBasis: .max
        )

        XCTAssertEqual(state.selectedUsedPercent, 82)
        XCTAssertEqual(state.selectedWindowStatus?.label, "주간")
        XCTAssertEqual(state.phase, .fast)
    }

    func testWeeklyOnlyCodexUsageFallsBackFromFiveHourBasisAndKeepsPanelAvailable() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let weeklyResetsAt = 1_800_345_600
        let report = Self.report(
            fiveHourUsedPercent: nil,
            weeklyUsedPercent: 82,
            weeklyResetsAt: weeklyResetsAt
        )
        let snapshot = CodexUsageCacheSnapshot(
            cachedAt: 1_800_000_000,
            staleAfterSeconds: 120,
            report: report,
            error: nil
        )
        let state = UsageMonitorState(
            report: report,
            cacheSnapshot: snapshot,
            errorMessage: nil,
            displayBasis: .fiveHour,
            runnerEvaluationDate: now
        )

        XCTAssertEqual(state.selectedUsedPercent, 82)
        XCTAssertEqual(state.selectedWindowStatus?.label, "주간")
        XCTAssertEqual(state.phase, .fast)
        XCTAssertEqual(
            try XCTUnwrap(state.codexPanelSummary(now: now, calendar: Self.utcCalendar)).statusDetail,
            "기준 주간 82% 사용 / 18% 남음"
        )
        XCTAssertEqual(state.nextResetGlance(now: now), "다음 초기화: 주간 96시간 후")
        XCTAssertTrue(state.toolTip.contains("5시간 현재 제공되지 않음"))
        XCTAssertNotEqual(state.codexDataStatus.title, "5시간 현재 미제공")
        XCTAssertNotEqual(state.codexDataStatus.tone, .warning)
        XCTAssertNil(state.codexFiveHourPaceProjection)
    }

    func testWeeklyOnlyReadyCacheAndHistoryIsHealthyWithoutFiveHourWarning() {
        let weeklyReset = 1_800_604_800
        let report = Self.report(
            fiveHourUsedPercent: nil,
            weeklyUsedPercent: 22,
            weeklyResetsAt: weeklyReset
        )
        let state = UsageMonitorState(
            report: report,
            cacheSnapshot: Self.cacheSnapshot(cachedAt: Int(Date().timeIntervalSince1970), report: report),
            weeklyUsageHistory: CodexUsageWeeklyHistory(samples: [
                Self.weeklySample(recordedAt: 1_800_000_000, remainingPercent: 78, resetsAt: weeklyReset)
            ]),
            resetWindowHistory: CodexUsageResetWindowHistory(records: [
                Self.resetWindowRecord(resetsAt: weeklyReset, finalUsedPercent: 22)
            ]),
            errorMessage: nil
        )

        XCTAssertNil(state.codexLimit?.fiveHour)
        XCTAssertEqual(state.codexDataStatus.tone, .ok)
        XCTAssertEqual(state.codexDataStatus.title, "데이터 정상")
        XCTAssertEqual(state.codexDataStatus.detail, "cache 최신 · weekly 1 · reset 1")
        XCTAssertFalse(state.codexDataStatus.detail.contains("sample"))
        XCTAssertFalse(state.codexDataStatus.detail.contains("record"))
    }

    func testRestoredFiveHourWindowResumesFiveHourBasis() {
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 25, weeklyUsedPercent: 82),
            cacheSnapshot: nil,
            errorMessage: nil,
            displayBasis: .fiveHour
        )

        XCTAssertEqual(state.selectedUsedPercent, 25)
        XCTAssertEqual(state.selectedWindowStatus?.label, "5시간")
    }

    func testSelectedProviderModeIsTheOnlyRunnerSourceAndNeverFallsBack() {
        let now = Int(Date().timeIntervalSince1970)
        let preview = Self.claudePreview(observedAt: now, usedPercent: 96)
        let claudeMode = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 20, weeklyUsedPercent: 30),
            cacheSnapshot: nil,
            errorMessage: nil,
            claudeUsagePreview: preview,
            usageProviderMode: .claude,
            runnerEvaluationDate: Date(timeIntervalSince1970: TimeInterval(now))
        )
        let codexMode = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 20, weeklyUsedPercent: 30),
            cacheSnapshot: nil,
            errorMessage: nil,
            claudeUsagePreview: preview,
            usageProviderMode: .codex,
            runnerEvaluationDate: Date(timeIntervalSince1970: TimeInterval(now))
        )
        let stale = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 99, weeklyUsedPercent: 99),
            cacheSnapshot: nil,
            errorMessage: nil,
            claudeUsagePreview: Self.claudePreview(observedAt: now - 1_000, usedPercent: 99),
            usageProviderMode: .claude,
            runnerEvaluationDate: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(claudeMode.phase, .sprint)
        XCTAssertEqual(claudeMode.codexPhase, .calm)
        XCTAssertEqual(codexMode.phase, .calm)
        XCTAssertEqual(stale.phase, .calm)
        XCTAssertEqual(stale.codexPhase, .sprint)
        XCTAssertEqual(claudeMode.codexPanelSummary()?.statusTitle, claudeMode.codexPhase.statusLabel)
    }

    func testSelectedUsageSourcePolicyDoesNotEvaluateCodexCacheOutsideCodexMode() {
        XCTAssertTrue(SelectedUsageSourcePolicy.shouldEvaluateCodexCache(for: .codex))
        XCTAssertFalse(SelectedUsageSourcePolicy.shouldEvaluateCodexCache(for: .grok))
        XCTAssertFalse(SelectedUsageSourcePolicy.shouldEvaluateCodexCache(for: .claude))
        XCTAssertTrue(SelectedUsageSourcePolicy.shouldLoadClaudePreview(for: .claude))
        XCTAssertFalse(SelectedUsageSourcePolicy.shouldLoadClaudePreview(for: .grok))
        XCTAssertFalse(SelectedUsageSourcePolicy.shouldLoadClaudePreview(for: .codex))
        XCTAssertTrue(SelectedUsageSourcePolicy.shouldLoadGrokCache(for: .grok))
        XCTAssertFalse(SelectedUsageSourcePolicy.shouldLoadGrokCache(for: .codex))
    }

    func testSelectedUsageSourcePolicyLoadsBothVisibleCachesWithoutFallback() {
        let dualCodexMain = UsageProviderSelection(
            enabled: [.codex, .grok],
            main: .codex,
            detailGraphVisible: true
        )
        let dualGrokMain = UsageProviderSelection(
            enabled: [.codex, .grok],
            main: .grok,
            detailGraphVisible: true
        )
        let grokOnly = UsageProviderSelection(enabled: .grok, main: .grok, detailGraphVisible: true)

        XCTAssertTrue(SelectedUsageSourcePolicy.shouldEvaluateCodexCache(for: dualCodexMain))
        XCTAssertTrue(SelectedUsageSourcePolicy.shouldLoadGrokCache(for: dualCodexMain))
        XCTAssertTrue(SelectedUsageSourcePolicy.shouldEvaluateCodexCache(for: dualGrokMain))
        XCTAssertTrue(SelectedUsageSourcePolicy.shouldLoadGrokCache(for: dualGrokMain))
        XCTAssertFalse(SelectedUsageSourcePolicy.shouldLoadClaudePreview(for: dualCodexMain))
        XCTAssertFalse(SelectedUsageSourcePolicy.shouldEvaluateCodexCache(for: grokOnly))
        XCTAssertTrue(SelectedUsageSourcePolicy.shouldLoadGrokCache(for: grokOnly))
        XCTAssertFalse(
            SelectedUsageSourcePolicy.shouldEvaluateCodexCache(for: .claude, selection: dualCodexMain)
        )
        XCTAssertFalse(SelectedUsageSourcePolicy.shouldLoadGrokCache(for: .claude, selection: dualCodexMain))
        XCTAssertTrue(
            SelectedUsageSourcePolicy.shouldEvaluateCodexCache(for: .grok, selection: dualGrokMain)
        )
        XCTAssertTrue(SelectedUsageSourcePolicy.shouldLoadGrokCache(for: .codex, selection: dualCodexMain))
    }

    func testVisibleSettingsModesHideClaudeAndKeepGrok() {
        XCTAssertEqual(UsageProviderMode.visibleCases, [.codex, .grok])
        XCTAssertTrue(UsageProviderMode.allCases.contains(.claude))
        XCTAssertFalse(UsageProviderMode.claude.isVisibleInSettings)
        XCTAssertEqual(UsageProviderMode.grok.label, "Grok")
    }

    func testGrokModeDoesNotUseCodexRunnerOrTooltip() {
        let now = 1_900_000_000
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 99, weeklyUsedPercent: 99),
            cacheSnapshot: nil,
            errorMessage: nil,
            claudeUsagePreview: Self.claudePreview(observedAt: now, usedPercent: 96),
            usageProviderMode: .grok,
            runnerEvaluationDate: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(state.phase, .calm)
        XCTAssertEqual(state.codexPhase, .sprint)
        XCTAssertTrue(state.toolTip.hasPrefix("Grok 사용량:"))
        XCTAssertFalse(state.toolTip.contains("코덱스"))
        XCTAssertFalse(state.toolTip.contains("Claude"))
        XCTAssertNil(state.nextResetGlance(now: Date(timeIntervalSince1970: TimeInterval(now))))
    }

    func testGrokWeeklyCacheDrivesRunnerWithoutCodexFallback() throws {
        let now = 1_900_000_000
        let weekly = try XCTUnwrap(GrokUsageWeeklyWindow(usedPercent: 96, resetsAt: now + 3_600))
        let preview = GrokUsagePreviewState(
            isEnabled: true,
            cacheSnapshot: GrokUsageCacheSnapshot(
                fetchedAt: now,
                lastUsageObservedAt: now,
                staleAfterSeconds: 180,
                weekly: weekly,
                issue: nil
            ),
            history: .empty,
            loadIssue: nil
        )
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 20, weeklyUsedPercent: 30),
            cacheSnapshot: nil,
            errorMessage: nil,
            grokUsage: preview,
            usageProviderMode: .grok,
            runnerEvaluationDate: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(state.phase, .sprint)
        XCTAssertEqual(state.codexPhase, .calm)
        XCTAssertEqual(state.toolTip, "Grok 사용량: 96% 주간")
        XCTAssertEqual(
            state.nextResetGlance(now: Date(timeIntervalSince1970: TimeInterval(now))),
            "다음 초기화: 주간 1시간 후"
        )
    }

    func testMainProviderRuntimeIgnoresAuxiliaryHighUsageAndStale() throws {
        let now = 1_900_000_000
        let dualCodexMain = UsageProviderSelection(
            enabled: [.codex, .grok],
            main: .codex,
            detailGraphVisible: true
        )
        let dualGrokMain = UsageProviderSelection(
            enabled: [.codex, .grok],
            main: .grok,
            detailGraphVisible: true
        )
        let grokSprint = try XCTUnwrap(GrokUsageWeeklyWindow(usedPercent: 96, resetsAt: now + 3_600))
        let grokActive = try XCTUnwrap(GrokUsageWeeklyWindow(usedPercent: 55, resetsAt: now + 3_600))
        let grokStale = GrokUsagePreviewState(
            isEnabled: true,
            cacheSnapshot: GrokUsageCacheSnapshot(
                fetchedAt: now,
                lastUsageObservedAt: now,
                staleAfterSeconds: 60,
                weekly: grokSprint,
                issue: nil
            ),
            history: .empty,
            loadIssue: nil
        )
        let grokFreshSprint = GrokUsagePreviewState(
            isEnabled: true,
            cacheSnapshot: GrokUsageCacheSnapshot(
                fetchedAt: now,
                lastUsageObservedAt: now,
                staleAfterSeconds: 900,
                weekly: grokSprint,
                issue: nil
            ),
            history: .empty,
            loadIssue: nil
        )
        let grokFreshActive = GrokUsagePreviewState(
            isEnabled: true,
            cacheSnapshot: GrokUsageCacheSnapshot(
                fetchedAt: now,
                lastUsageObservedAt: now,
                staleAfterSeconds: 900,
                weekly: grokActive,
                issue: nil
            ),
            history: .empty,
            loadIssue: nil
        )
        let evaluationDate = Date(timeIntervalSince1970: TimeInterval(now))
        let staleDate = Date(timeIntervalSince1970: TimeInterval(now + 120))
        let codexMain = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 20, weeklyUsedPercent: 30),
            cacheSnapshot: nil,
            errorMessage: nil,
            grokUsage: grokFreshSprint,
            usageProviderMode: .codex,
            usageProviderSelection: dualCodexMain,
            runnerEvaluationDate: evaluationDate
        )
        let grokMain = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 99, weeklyUsedPercent: 99),
            cacheSnapshot: nil,
            errorMessage: nil,
            grokUsage: grokFreshActive,
            usageProviderMode: .grok,
            usageProviderSelection: dualGrokMain,
            runnerEvaluationDate: evaluationDate
        )
        let grokMainStale = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 99, weeklyUsedPercent: 99),
            cacheSnapshot: nil,
            errorMessage: nil,
            grokUsage: grokStale,
            usageProviderMode: .grok,
            usageProviderSelection: dualGrokMain,
            runnerEvaluationDate: staleDate
        )

        XCTAssertEqual(codexMain.runtimeProviderMode, .codex)
        XCTAssertEqual(codexMain.phase, .calm)
        XCTAssertEqual(codexMain.codexPhase, .calm)
        XCTAssertTrue(codexMain.toolTip.hasPrefix("코덱스 사용량:"))
        XCTAssertFalse(codexMain.toolTip.contains("Grok"))
        XCTAssertEqual(grokMain.runtimeProviderMode, .grok)
        XCTAssertEqual(grokMain.phase, .active)
        XCTAssertEqual(grokMain.codexPhase, .sprint)
        XCTAssertEqual(grokMain.toolTip, "Grok 사용량: 55% 주간")
        XCTAssertEqual(grokMainStale.phase, .calm)
        XCTAssertEqual(grokMainStale.codexPhase, .sprint)
        XCTAssertEqual(codexMain.withRefreshing(true).usageProviderSelection, dualCodexMain)
        XCTAssertEqual(
            grokMain.withSystemMetrics(
                .unavailable,
                sleepPreventionStatus: .disabled,
                sleepPreventionTriggerStatus: .disabled,
                privilegedHelperInstallSnapshot: .missing
            ).usageProviderSelection,
            dualGrokMain
        )
        XCTAssertEqual(codexMain.nextResetGlance(now: evaluationDate), nil)
        XCTAssertEqual(grokMain.nextResetGlance(now: evaluationDate), "다음 초기화: 주간 1시간 후")
        XCTAssertNil(grokMainStale.nextResetGlance(now: staleDate))
    }

    func testGrokEmptyStateAsksForLoginInsteadOfBareMissingCache() throws {
        let now = 1_900_000_000
        let unavailable = GrokUsagePreviewState(
            isEnabled: true,
            cacheSnapshot: GrokUsageCacheSnapshot(
                fetchedAt: now,
                lastUsageObservedAt: nil,
                staleAfterSeconds: 180,
                weekly: nil,
                issue: GrokUsageCacheIssue(code: "auth-unavailable", recordedAt: now)
            ),
            history: .empty,
            loadIssue: nil
        )
        XCTAssertEqual(unavailable.statusTitle(now: Date(timeIntervalSince1970: TimeInterval(now))), "로그인 필요")
        XCTAssertEqual(unavailable.emptyStateTitle(), "Grok 로그인 필요")
        XCTAssertTrue(unavailable.needsLoginGuidance)
        XCTAssertTrue(unavailable.emptyStateDetail().contains("grok login"))

        let waiting = GrokUsagePreviewState(
            isEnabled: true,
            cacheSnapshot: nil,
            history: .empty,
            loadIssue: nil
        )
        XCTAssertEqual(waiting.emptyStateTitle(), "Grok 로그인 필요")
        XCTAssertTrue(waiting.needsLoginGuidance)

        let guide = GrokLoginGuide()
        XCTAssertEqual(guide.standaloneCommand, "grok login")
        XCTAssertTrue(guide.appleScriptSource().contains("grok login"))
        XCTAssertTrue(guide.appleScriptSource().contains("Terminal"))
        XCTAssertTrue(unavailable.showsLoginActions)

        let weekly = try XCTUnwrap(GrokUsageWeeklyWindow(usedPercent: 10, resetsAt: now + 3_600))
        let expired = GrokUsagePreviewState(
            isEnabled: true,
            cacheSnapshot: GrokUsageCacheSnapshot(
                fetchedAt: now,
                lastUsageObservedAt: now,
                staleAfterSeconds: 180,
                weekly: weekly,
                issue: GrokUsageCacheIssue(code: "auth-expired", recordedAt: now)
            ),
            history: .empty,
            loadIssue: nil
        )
        XCTAssertEqual(expired.statusTitle(now: Date(timeIntervalSince1970: TimeInterval(now))), "세션 갱신 실패")
        XCTAssertEqual(expired.emptyStateTitle(), "Grok 세션 갱신 실패")
        XCTAssertFalse(expired.needsLoginGuidance)
        XCTAssertTrue(expired.showsLoginActions)
        XCTAssertEqual(expired.weeklyCardUnavailableText(), "세션 갱신 실패")
        XCTAssertTrue(expired.emptyStateDetail().contains("grok login"))

        let lookupFailed = GrokUsagePreviewState(
            isEnabled: true,
            cacheSnapshot: GrokUsageCacheSnapshot(
                fetchedAt: now,
                lastUsageObservedAt: now,
                staleAfterSeconds: 180,
                weekly: weekly,
                issue: GrokUsageCacheIssue(code: "request-failed", recordedAt: now)
            ),
            history: .empty,
            loadIssue: nil
        )
        XCTAssertEqual(lookupFailed.statusTitle(now: Date(timeIntervalSince1970: TimeInterval(now))), "조회 오류")
        XCTAssertEqual(lookupFailed.emptyStateTitle(), "Grok 조회 오류")
        XCTAssertFalse(lookupFailed.needsLoginGuidance)
        XCTAssertFalse(lookupFailed.showsLoginActions)
        XCTAssertTrue(lookupFailed.emptyStateDetail().contains("grok login이 필요한 상태가 아닙니다"))

        let missingWindow = GrokUsagePreviewState(
            isEnabled: true,
            cacheSnapshot: GrokUsageCacheSnapshot(
                fetchedAt: now,
                lastUsageObservedAt: now,
                staleAfterSeconds: 180,
                weekly: try XCTUnwrap(GrokUsageWeeklyWindow(usedPercent: 99, resetsAt: now)),
                issue: GrokUsageCacheIssue(code: "weekly-window-missing", recordedAt: now)
            ),
            history: .empty,
            loadIssue: nil
        )
        XCTAssertEqual(missingWindow.emptyStateTitle(), "Grok 주간 window 없음")
        XCTAssertFalse(missingWindow.needsLoginGuidance)
        XCTAssertFalse(missingWindow.showsLoginActions)
    }

    func testGrokWeeklyHistoryMapsToSharedRemainingChartWithHoverLabels() throws {
        let resetsAt = 1_787_367_003
        let recordedAt = resetsAt - (6 * 24 * 60 * 60)
        let weekly = try XCTUnwrap(GrokUsageWeeklyWindow(usedPercent: 75, resetsAt: resetsAt))
        let grokSample = try XCTUnwrap(
            GrokUsageHistorySample(
                recordedAt: recordedAt,
                usedPercent: 75,
                remainingPercent: 25,
                resetsAt: resetsAt
            )
        )
        let window = try XCTUnwrap(GrokWeeklyRemainingHistoryAdapter.weeklyWindow(weekly))
        let history = GrokWeeklyRemainingHistoryAdapter.history(
            GrokUsageHistory(samples: [grokSample]),
            currentWeekly: weekly,
            currentRecordedAt: recordedAt
        )
        let chart = WeeklyRemainingHistoryChart(
            history: history,
            weeklyWindow: window,
            currentSample: history.samples.first,
            calendar: Self.utcCalendar
        )

        XCTAssertEqual(window.windowDurationMins, 10_080)
        XCTAssertEqual(history.samples.count, 1)
        XCTAssertEqual(chart.latestActualPoint?.remainingPercent, 25)
        XCTAssertFalse(chart.dayMarkers.isEmpty)
        XCTAssertTrue(chart.dayMarkers.contains { $0.hoverLabel.contains("%") })
        XCTAssertTrue(chart.points.contains { $0.remainingPercent == 100 && $0.isResetAnchor })

        let model = try XCTUnwrap(CodexUsageHistoryComparisonModel(
            history: history,
            resetWindowHistory: .empty,
            weeklyWindow: window,
            currentReport: nil,
            currentTimestamp: recordedAt,
            calendar: Self.utcCalendar
        ))
        XCTAssertEqual(model.currentChart.dayMarkers.map(\.id), chart.dayMarkers.map(\.id))
        XCTAssertEqual(
            model.currentChart.dayMarkers.map(\.hoverLabel),
            chart.dayMarkers.map(\.hoverLabel)
        )
    }

    func testGrokWeeklyHistoryComparisonModelFillsCompletedDayHoverWithoutCodexReport() throws {
        let calendar = Self.utcCalendar
        let startDate = try XCTUnwrap(calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: 1,
            hour: 0,
            minute: 21,
            second: 23
        )))
        let start = Int(startDate.timeIntervalSince1970)
        let reset = start + 604_800
        let currentRecordedAt = start + 2 * 86_400 + 17 * 3_600 + 2 * 60
        let weekly = try XCTUnwrap(GrokUsageWeeklyWindow(usedPercent: 36, resetsAt: reset))
        let history = GrokWeeklyRemainingHistoryAdapter.history(
            GrokUsageHistory(samples: [
                try XCTUnwrap(GrokUsageHistorySample(
                    recordedAt: start + 86_400 + 18 * 3_600,
                    usedPercent: 13,
                    remainingPercent: 87,
                    resetsAt: reset
                )),
                try XCTUnwrap(GrokUsageHistorySample(
                    recordedAt: start + 2 * 86_400 - 5 * 60,
                    usedPercent: 17,
                    remainingPercent: 83,
                    resetsAt: reset
                )),
                try XCTUnwrap(GrokUsageHistorySample(
                    recordedAt: start + 2 * 86_400 + 17 * 3_600,
                    usedPercent: 36,
                    remainingPercent: 64,
                    resetsAt: reset
                ))
            ]),
            currentWeekly: weekly,
            currentRecordedAt: currentRecordedAt
        )
        let window = try XCTUnwrap(GrokWeeklyRemainingHistoryAdapter.weeklyWindow(weekly))
        let model = try XCTUnwrap(CodexUsageHistoryComparisonModel(
            history: history,
            resetWindowHistory: .empty,
            weeklyWindow: window,
            currentReport: nil,
            currentTimestamp: currentRecordedAt,
            calendar: calendar
        ))

        XCTAssertEqual(model.currentChart.dayMarkers.map(\.id), [0, 1, 2])
        XCTAssertEqual(
            model.currentChart.dayMarkers.map(\.hoverLabel),
            ["6/1 월 종료 · 100%", "6/2 화 종료 · 83%", "6/3 수 · 64%"]
        )
        XCTAssertEqual(model.currentChart.dayMarkers[0].point.recordedAt, start + 86_400)
        XCTAssertEqual(model.currentChart.dayMarkers[2].point.recordedAt, currentRecordedAt)
    }

    func testGrokWeeklyHistoryComparisonModelHoversOnlyCurrentDayAfterReset() throws {
        let calendar = Self.utcCalendar
        let start = Self.timestamp(year: 2026, month: 8, day: 22, hour: 11, minute: 50)
        let reset = start + 604_800
        let currentRecordedAt = start + 10 * 60
        let weekly = try XCTUnwrap(GrokUsageWeeklyWindow(usedPercent: 4, resetsAt: reset))
        let history = GrokWeeklyRemainingHistoryAdapter.history(
            GrokUsageHistory(samples: [
                try XCTUnwrap(GrokUsageHistorySample(
                    recordedAt: currentRecordedAt,
                    usedPercent: 4,
                    remainingPercent: 96,
                    resetsAt: reset
                ))
            ]),
            currentWeekly: weekly,
            currentRecordedAt: currentRecordedAt
        )
        let window = try XCTUnwrap(GrokWeeklyRemainingHistoryAdapter.weeklyWindow(weekly))
        let model = try XCTUnwrap(CodexUsageHistoryComparisonModel(
            history: history,
            resetWindowHistory: .empty,
            weeklyWindow: window,
            currentReport: nil,
            currentTimestamp: currentRecordedAt,
            calendar: calendar
        ))

        XCTAssertEqual(model.currentChart.dayMarkers.map(\.id), [0])
        XCTAssertTrue(model.currentChart.dayMarkers[0].hoverLabel.contains("96%"))
        XCTAssertFalse(model.currentChart.dayMarkers.contains { $0.id == 1 })
    }

    func testCalendarMidnightBaselineMovesHoverToSundayAfterLocalMidnight() throws {
        let calendar = Self.utcCalendar
        let start = Self.timestamp(year: 2026, month: 8, day: 22, hour: 11, minute: 50)
        let reset = start + 604_800
        let sundayMorning = Self.timestamp(year: 2026, month: 8, day: 23, hour: 11, minute: 18)
        let currentSample = Self.weeklySample(
            recordedAt: sundayMorning,
            remainingPercent: 75,
            resetsAt: reset
        )

        let midnightChart = WeeklyRemainingHistoryChart(
            history: CodexUsageWeeklyHistory(samples: [currentSample]),
            weeklyWindow: Self.weeklyWindow(remainingPercent: 75, resetsAt: reset),
            currentSample: currentSample,
            calendar: calendar,
            dateBaseline: .calendarMidnight
        )
        XCTAssertEqual(midnightChart.dayGridPositions.count, 9)
        XCTAssertEqual(midnightChart.dayMarkers.map(\.id), [0, 1])
        XCTAssertTrue(midnightChart.dayMarkers[0].hoverLabel.hasPrefix("8/22 토 종료"))
        XCTAssertTrue(midnightChart.dayMarkers[1].hoverLabel.hasPrefix("8/23 일"))
        XCTAssertTrue(midnightChart.dayMarkers[1].hoverLabel.contains("75%"))

        let resetChart = WeeklyRemainingHistoryChart(
            history: CodexUsageWeeklyHistory(samples: [currentSample]),
            weeklyWindow: Self.weeklyWindow(remainingPercent: 75, resetsAt: reset),
            currentSample: currentSample,
            calendar: calendar,
            dateBaseline: .resetWindow
        )
        XCTAssertEqual(resetChart.dayGridPositions.count, 8)
        XCTAssertEqual(resetChart.dayMarkers.map(\.id), [0])
        XCTAssertTrue(resetChart.dayMarkers[0].hoverLabel.hasPrefix("8/22 토"))
        XCTAssertFalse(resetChart.dayMarkers[0].hoverLabel.contains("종료"))
    }

    func testUsageGraphDateBaselineDefaultIsCalendarMidnight() {
        XCTAssertEqual(UsageGraphDateBaseline.defaultBaseline, .calendarMidnight)
        XCTAssertEqual(UsageGraphDateBaseline.calendarMidnight.label, "자정")
        XCTAssertEqual(UsageGraphDateBaseline.resetWindow.label, "리셋 시각")
    }

    func testClaudeModeTooltipAndResetNeverUseCodexFallback() {
        let now = 1_900_000_000
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 99, weeklyUsedPercent: 99),
            cacheSnapshot: nil,
            errorMessage: nil,
            claudeUsagePreview: Self.claudePreview(observedAt: now, usedPercent: 40),
            usageProviderMode: .claude,
            runnerEvaluationDate: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertTrue(state.toolTip.hasPrefix("Claude 사용량:"))
        XCTAssertFalse(state.toolTip.contains("코덱스"))
        XCTAssertTrue(state.nextResetGlance(
            now: Date(timeIntervalSince1970: TimeInterval(now))
        )?.contains("5시간") == true)
    }

    func testClaudeCurrentWindowExcludesExpiredWindowWhileKeepingFreshPartialWindow() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let usage = ClaudeStatusLineSnapshot(
            observedAt: Int(now.timeIntervalSince1970),
            fiveHour: try ClaudeUsageWindowSnapshot(
                usedPercent: 90,
                resetsAt: Int(now.timeIntervalSince1970) - 1
            ),
            sevenDay: try ClaudeUsageWindowSnapshot(
                usedPercent: 40,
                resetsAt: Int(now.timeIntervalSince1970) + 60_000
            )
        )
        let preview = ClaudeUsagePreviewState(
            isEnabled: true,
            cacheSnapshot: ClaudeUsageCacheSnapshot(
                lastEventAt: usage.observedAt,
                lastUsageObservedAt: usage.observedAt,
                staleAfterSeconds: 900,
                usage: usage,
                issue: nil
            ),
            history: .empty,
            loadIssue: nil
        )

        XCTAssertEqual(preview.status(now: now), .partial)
        XCTAssertEqual(preview.statusTitle(now: now), "일부 window 수신")
        XCTAssertNil(preview.currentWindow(.fiveHour, now: now))
        XCTAssertEqual(preview.currentWindow(.sevenDay, now: now)?.usedPercent, 40)
        XCTAssertEqual(preview.runnerUsedPercent(now: now), 40)
    }

    func testRunnerPhaseCapturesFreshnessUntilNextStateLoad() {
        let observedAt = 1_900_000_000
        let preview = Self.claudePreview(observedAt: observedAt, usedPercent: 96)
        let beforeStale = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 20, weeklyUsedPercent: 30),
            cacheSnapshot: nil,
            errorMessage: nil,
            claudeUsagePreview: preview,
            usageProviderMode: .claude,
            runnerEvaluationDate: Date(timeIntervalSince1970: TimeInterval(observedAt + 899))
        )
        let afterStale = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 20, weeklyUsedPercent: 30),
            cacheSnapshot: nil,
            errorMessage: nil,
            claudeUsagePreview: preview,
            usageProviderMode: .claude,
            runnerEvaluationDate: Date(timeIntervalSince1970: TimeInterval(observedAt + 901))
        )

        XCTAssertEqual(beforeStale.phase, .sprint)
        XCTAssertEqual(afterStale.phase, .calm)
        XCTAssertEqual(beforeStale.phase, .sprint, "old state must keep its captured phase for timer comparison")
    }

    func testStateCopiesPreserveUsageProviderMode() {
        let now = Int(Date().timeIntervalSince1970)
        let preview = Self.claudePreview(observedAt: now, usedPercent: 55)
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 10, weeklyUsedPercent: 20),
            cacheSnapshot: nil,
            errorMessage: nil,
            claudeUsagePreview: preview,
            usageProviderMode: .claude,
            runnerEvaluationDate: Date(timeIntervalSince1970: TimeInterval(now))
        )

        XCTAssertEqual(state.withRefreshing(true).claudeUsagePreview, preview)
        XCTAssertEqual(state.withRefreshing(true).usageProviderMode, .claude)
        XCTAssertEqual(
            state.withSystemMetrics(
                .unavailable,
                sleepPreventionStatus: .disabled,
                sleepPreventionTriggerStatus: .disabled,
                privilegedHelperInstallSnapshot: .missing
            ).claudeUsagePreview,
            preview
        )
    }

    func testUsageProviderMigrationDefaultsExistingUsersToCodexAndRemovesLegacyKeys() throws {
        let suite = "UsageMonitorStateTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "claudeUsagePreviewEnabled")
        defaults.set("claude", forKey: "usagePreviewProvider")
        defaults.set(true, forKey: "claudeRunnerPreviewEnabled")
        defaults.set(true, forKey: "claudeUsageNotificationsEnabled")
        RunnerPreferences.registerDefaults(defaults: defaults)

        XCTAssertEqual(RunnerPreferences(defaults: defaults).usageProviderMode, .codex)
        XCTAssertEqual(defaults.string(forKey: RunnerPreferences.usageProviderModeKey), "codex")
        XCTAssertNil(defaults.object(forKey: "claudeUsagePreviewEnabled"))
        XCTAssertNil(defaults.object(forKey: "usagePreviewProvider"))
        XCTAssertNil(defaults.object(forKey: "claudeRunnerPreviewEnabled"))
        XCTAssertNil(defaults.object(forKey: "claudeUsageNotificationsEnabled"))
    }

    func testUsageProviderMigrationPreservesValidModeAndNormalizesInvalidMode() throws {
        let suite = "UsageMonitorStateTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set("grok", forKey: RunnerPreferences.usageProviderModeKey)
        RunnerPreferences.migrateUsageProviderMode(defaults: defaults)
        RunnerPreferences.migrateUsageProviderMode(defaults: defaults)
        XCTAssertEqual(RunnerPreferences(defaults: defaults).usageProviderMode, .grok)

        defaults.set("claude", forKey: RunnerPreferences.usageProviderModeKey)
        RunnerPreferences.migrateUsageProviderMode(defaults: defaults)
        XCTAssertEqual(RunnerPreferences(defaults: defaults).usageProviderMode, .codex)
        XCTAssertEqual(defaults.string(forKey: RunnerPreferences.usageProviderModeKey), "codex")

        defaults.set("invalid", forKey: RunnerPreferences.usageProviderModeKey)
        RunnerPreferences.migrateUsageProviderMode(defaults: defaults)
        XCTAssertEqual(RunnerPreferences(defaults: defaults).usageProviderMode, .codex)
    }

    func testUsageProviderMigrationKeepsClaudeOnlyWhenHiddenReenableIsOn() throws {
        let suite = "UsageMonitorStateTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set("claude", forKey: RunnerPreferences.usageProviderModeKey)
        RunnerPreferences.setClaudeUsageProviderReenabled(true, defaults: defaults)
        RunnerPreferences.migrateUsageProviderMode(defaults: defaults)
        XCTAssertEqual(RunnerPreferences(defaults: defaults).usageProviderMode, .claude)
        XCTAssertEqual(defaults.string(forKey: RunnerPreferences.usageProviderModeKey), "claude")

        RunnerPreferences.setClaudeUsageProviderReenabled(false, defaults: defaults)
        RunnerPreferences.migrateUsageProviderMode(defaults: defaults)
        XCTAssertEqual(RunnerPreferences(defaults: defaults).usageProviderMode, .codex)
        XCTAssertEqual(defaults.string(forKey: RunnerPreferences.usageProviderModeKey), "codex")
    }

    func testIncompleteCodexReportDoesNotLookLikeZeroUsage() {
        let state = UsageMonitorState(
            report: Self.incompleteCodexReport(),
            cacheSnapshot: nil,
            errorMessage: nil,
            displayBasis: .weekly
        )

        XCTAssertNil(state.codexLimit)
        XCTAssertNil(state.selectedWindowStatus)
        XCTAssertEqual(state.sourceLabel, "확인 불가")
        XCTAssertEqual(state.toolTip, "코덱스 사용량 확인 불가")
    }

    func testResetSummaryShowsRemainingTimeAndCompactSameDayTime() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let calendar = Self.utcCalendar

        XCTAssertEqual(
            UsageWindowStatus.resetSummary(
                resetsAt: 1_800_007_200,
                now: now,
                calendar: calendar
            ),
            "초기화까지 2시간 남음 · 10:00"
        )
    }

    func testResetSummaryShowsCompactFutureDayTime() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let calendar = Self.utcCalendar

        XCTAssertEqual(
            UsageWindowStatus.resetSummary(
                resetsAt: 1_800_345_600,
                now: now,
                calendar: calendar
            ),
            "초기화까지 4일 남음 · 1/19 08:00"
        )
    }

    func testResetSummaryHandlesMissingAndPastResetTime() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let calendar = Self.utcCalendar

        XCTAssertEqual(
            UsageWindowStatus.resetSummary(resetsAt: nil, now: now, calendar: calendar),
            "초기화 시각 알 수 없음"
        )
        XCTAssertEqual(
            UsageWindowStatus.resetSummary(
                resetsAt: 1_799_999_940,
                now: now,
                calendar: calendar
            ),
            "초기화 확인 중 · 07:59"
        )
    }

    func testCodexPanelSummaryConnectsRiskResetsAndNotificationThresholds() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let state = UsageMonitorState(
            report: Self.report(
                fiveHourUsedPercent: 83.5,
                weeklyUsedPercent: 36,
                fiveHourResetsAt: 1_800_007_200,
                weeklyResetsAt: 1_800_345_600
            ),
            cacheSnapshot: nil,
            errorMessage: nil,
            displayBasis: .max
        )

        let summary = try XCTUnwrap(state.codexPanelSummary(now: now, calendar: Self.utcCalendar))

        XCTAssertEqual(summary.statusTitle, "사용량 높음")
        XCTAssertEqual(summary.statusDetail, "기준 5시간 83.5% 사용 / 16.5% 남음")
        XCTAssertEqual(summary.notificationThresholdSummary, "알림 기준 80/95/100% · reset 30분 전")
        XCTAssertEqual(
            summary.resetCountdowns,
            [
                CodexUsagePanelSummary.ResetCountdown(label: "5시간 reset", value: "2시간 남음 · 10:00"),
                CodexUsagePanelSummary.ResetCountdown(label: "주간 reset", value: "4일 남음 · 1/19 08:00")
            ]
        )
    }

    func testCodexPanelSummaryUsesLimitTitleWhenReportMarksLimitReached() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let state = UsageMonitorState(
            report: Self.report(
                fiveHourUsedPercent: 68,
                weeklyUsedPercent: 42,
                fiveHourResetsAt: 1_800_003_600,
                weeklyResetsAt: 1_800_604_800,
                rateLimitReachedType: "primary"
            ),
            cacheSnapshot: nil,
            errorMessage: nil
        )

        let summary = try XCTUnwrap(state.codexPanelSummary(now: now, calendar: Self.utcCalendar))

        XCTAssertEqual(summary.statusTitle, "한도 도달")
        XCTAssertEqual(summary.statusDetail, "기준 5시간 68% 사용 / 32% 남음")
        XCTAssertEqual(summary.resetCountdowns.first?.value, "1시간 남음 · 09:00")
    }

    func testNextResetGlanceUsesClosestUsageWindowDirectly() {
        let now = 1_800_000_000
        let report = Self.report(
            fiveHourUsedPercent: 68,
            weeklyUsedPercent: 42,
            fiveHourResetsAt: now + 604_800,
            weeklyResetsAt: now + 30 * 60
        )
        let state = UsageMonitorState(
            report: report,
            cacheSnapshot: Self.cacheSnapshot(
                cachedAt: now,
                report: report
            ),
            errorMessage: nil
        )

        XCTAssertEqual(
            state.nextResetGlance(now: Date(timeIntervalSince1970: TimeInterval(now))),
            "다음 초기화: 주간 30분 후"
        )
    }

    func testNextResetGlanceReturnsNilWhenUsageWindowsDoNotHaveResetTimes() {
        let now = 1_800_000_000
        let state = UsageMonitorState(
            report: Self.report(
                fiveHourUsedPercent: 12,
                weeklyUsedPercent: 75
            ),
            cacheSnapshot: nil,
            errorMessage: nil
        )

        XCTAssertNil(state.nextResetGlance(now: Date(timeIntervalSince1970: TimeInterval(now))))
    }

    func testCodexPanelDoesNotExposeSessionPlanDurations() throws {
        let state = UsageMonitorState(
            report: Self.report(
                fiveHourUsedPercent: 12,
                weeklyUsedPercent: 75
            ),
            cacheSnapshot: nil,
            errorMessage: nil
        )

        let summary = try XCTUnwrap(state.codexPanelSummary())

        XCTAssertFalse(summary.statusDetail.contains("1시간"))
        XCTAssertFalse(summary.statusDetail.contains("3시간"))
    }

    func testNextResetTooltipSummary() {
        let now = 1_800_000_000
        let report = Self.report(
            fiveHourUsedPercent: 68,
            weeklyUsedPercent: 42,
            fiveHourResetsAt: now + 3_600,
            weeklyResetsAt: now + 604_800
        )
        let state = UsageMonitorState(
            report: report,
            cacheSnapshot: Self.cacheSnapshot(
                cachedAt: now,
                report: report
            ),
            errorMessage: nil
        )

        XCTAssertEqual(
            state.nextResetGlance(now: Date(timeIntervalSince1970: TimeInterval(now))),
            "다음 초기화: 5시간 1시간 후"
        )
    }

    func testCodexDataStatusReportsReadyCacheAndHistory() {
        let weeklyReset = 1_800_604_800
        let report = Self.report(
            fiveHourUsedPercent: 8,
            weeklyUsedPercent: 22,
            weeklyResetsAt: weeklyReset
        )
        let state = UsageMonitorState(
            report: report,
            cacheSnapshot: Self.cacheSnapshot(cachedAt: Int(Date().timeIntervalSince1970), report: report),
            weeklyUsageHistory: CodexUsageWeeklyHistory(samples: [
                Self.weeklySample(recordedAt: 1_800_000_000, remainingPercent: 78, resetsAt: weeklyReset)
            ]),
            resetWindowHistory: CodexUsageResetWindowHistory(records: [
                Self.resetWindowRecord(resetsAt: weeklyReset, finalUsedPercent: 22)
            ]),
            errorMessage: nil
        )

        XCTAssertEqual(
            state.codexDataStatus,
            CodexUsageDataStatus(
                tone: .ok,
                systemImage: "checkmark.circle.fill",
                title: "데이터 정상",
                detail: "cache 최신 · weekly 1 · reset 1"
            )
        )
    }

    func testCodexDataStatusReportsHistorySampleWaiting() {
        let report = Self.report(fiveHourUsedPercent: 8, weeklyUsedPercent: 22)
        let state = UsageMonitorState(
            report: report,
            cacheSnapshot: Self.cacheSnapshot(cachedAt: Int(Date().timeIntervalSince1970), report: report),
            weeklyUsageHistory: .empty,
            resetWindowHistory: .empty,
            errorMessage: nil
        )

        XCTAssertEqual(state.codexDataStatus.tone, .waiting)
        XCTAssertEqual(state.codexDataStatus.title, "history 샘플 대기")
        XCTAssertEqual(state.codexDataStatus.detail, "그래프는 현재 cache 중심으로 표시")
    }

    func testCodexDataStatusSeparatesStaleAndErrorCache() {
        let report = Self.report(fiveHourUsedPercent: 8, weeklyUsedPercent: 22)
        let stale = UsageMonitorState(
            report: report,
            cacheSnapshot: Self.cacheSnapshot(
                cachedAt: 1_700_000_000,
                staleAfterSeconds: 120,
                report: report
            ),
            errorMessage: nil
        )
        let error = UsageMonitorState(
            report: report,
            cacheSnapshot: Self.cacheSnapshot(
                cachedAt: Int(Date().timeIntervalSince1970),
                report: report,
                error: CodexUsageCacheError(message: "redacted failure", recordedAt: 1_800_000_030)
            ),
            errorMessage: "redacted failure"
        )

        XCTAssertEqual(stale.codexDataStatus.title, "오래된 cache")
        XCTAssertEqual(stale.codexDataStatus.tone, .warning)
        XCTAssertEqual(error.codexDataStatus.title, "cache 오류")
        XCTAssertEqual(error.codexDataStatus.tone, .error)
    }

    func testCodexDataStatusFlagsMissingRequiredWindowsAsProtocolCheck() {
        let state = UsageMonitorState(
            report: Self.incompleteCodexReport(),
            cacheSnapshot: nil,
            errorMessage: nil
        )

        XCTAssertEqual(state.codexDataStatus.tone, .warning)
        XCTAssertEqual(state.codexDataStatus.title, "프로토콜 확인 필요")
        XCTAssertEqual(state.codexDataStatus.detail, "필수 주간 window 누락")
    }

    func testRefreshingPreservesPrivilegedHelperInstallSnapshot() {
        let snapshot = PrivilegedHelperInstallSnapshot(helperToolExists: true, launchDaemonExists: false)
        let state = UsageMonitorState(
            report: nil,
            cacheSnapshot: nil,
            errorMessage: nil,
            privilegedHelperInstallSnapshot: snapshot
        )

        XCTAssertEqual(state.withRefreshing(true).privilegedHelperInstallSnapshot, snapshot)
    }

    func testRefreshingPreservesWeeklyUsageHistory() {
        let history = CodexUsageWeeklyHistory(samples: [
            Self.weeklySample(recordedAt: 1_000, remainingPercent: 92, resetsAt: 1_000 + 604_800)
        ])
        let state = UsageMonitorState(
            report: nil,
            cacheSnapshot: nil,
            weeklyUsageHistory: history,
            errorMessage: nil
        )

        XCTAssertEqual(state.withRefreshing(true).weeklyUsageHistory, history)
    }

    func testRefreshingPreservesFiveHourUsageHistory() throws {
        let history = CodexUsageFiveHourHistory(samples: [
            try XCTUnwrap(CodexUsageFiveHourHistorySample(
                recordedAt: 1_000,
                windowDurationMins: 300,
                usedPercent: 24,
                resetsAt: 1_000 + 18_000
            ))
        ])
        let state = UsageMonitorState(
            report: nil,
            cacheSnapshot: nil,
            fiveHourUsageHistory: history,
            errorMessage: nil
        )

        XCTAssertEqual(state.withRefreshing(true).fiveHourUsageHistory, history)
    }

    func testRefreshingPreservesResetWindowHistory() {
        let resetHistory = CodexUsageResetWindowHistory(records: [
            Self.resetWindowRecord(resetsAt: 1_800_604_800, finalUsedPercent: 74)
        ])
        let state = UsageMonitorState(
            report: nil,
            cacheSnapshot: nil,
            resetWindowHistory: resetHistory,
            errorMessage: nil
        )

        XCTAssertEqual(state.withRefreshing(true).resetWindowHistory, resetHistory)
    }

    func testCodexHistoryComparisonModelExposesPastWindowPickerAndModes() throws {
        let currentReset = 1_800_604_800
        let pastReset = currentReset - 604_800
        let olderPastReset = pastReset - 604_800
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 12, weeklyUsedPercent: 32, weeklyResetsAt: currentReset),
            cacheSnapshot: nil,
            resetWindowHistory: CodexUsageResetWindowHistory(records: [
                Self.resetWindowRecord(resetsAt: currentReset, finalUsedPercent: 32),
                Self.resetWindowRecord(resetsAt: pastReset, finalUsedPercent: 74),
                Self.resetWindowRecord(resetsAt: olderPastReset, finalUsedPercent: 51)
            ]),
            errorMessage: nil
        )

        let model = try XCTUnwrap(CodexUsageHistoryComparisonModel(state: state, calendar: Self.utcCalendar))

        XCTAssertEqual(model.availableModes, [.current, .past, .overlay])
        XCTAssertEqual(model.pastWindows.map(\.key.resetsAt), [pastReset, olderPastReset])
        XCTAssertEqual(model.defaultPastWindowKey?.resetsAt, pastReset)
        XCTAssertEqual(model.overlaySeries?.finalUsageMarker.usedPercent, 74)
    }

    func testCodexHistoryComparisonModelKeepsHistoryModesVisibleWithoutPastWindows() throws {
        let currentReset = 1_800_604_800
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 12, weeklyUsedPercent: 32, weeklyResetsAt: currentReset),
            cacheSnapshot: nil,
            resetWindowHistory: CodexUsageResetWindowHistory(records: [
                Self.resetWindowRecord(resetsAt: currentReset, finalUsedPercent: 32),
                Self.resetWindowRecord(resetsAt: currentReset + 1, finalUsedPercent: 32)
            ]),
            errorMessage: nil
        )

        let model = try XCTUnwrap(CodexUsageHistoryComparisonModel(state: state, calendar: Self.utcCalendar))

        XCTAssertEqual(model.availableModes, [.current, .past, .overlay])
        XCTAssertTrue(model.pastWindows.isEmpty)
        XCTAssertNil(model.defaultPastWindowKey)
        XCTAssertNil(model.overlaySeries)
    }

    func testCodexHistoryComparisonModelExcludesRollingCurrentResetDuplicates() throws {
        let currentReset = 1_800_604_800
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 12, weeklyUsedPercent: 1, weeklyResetsAt: currentReset),
            cacheSnapshot: nil,
            resetWindowHistory: CodexUsageResetWindowHistory(records: [
                Self.resetWindowRecord(resetsAt: currentReset - 9 * 60, finalUsedPercent: 0),
                Self.resetWindowRecord(resetsAt: currentReset - 2 * 60, finalUsedPercent: 1),
                Self.resetWindowRecord(resetsAt: currentReset, finalUsedPercent: 1)
            ]),
            errorMessage: nil
        )

        let model = try XCTUnwrap(CodexUsageHistoryComparisonModel(state: state, calendar: Self.utcCalendar))

        XCTAssertTrue(model.pastWindows.isEmpty)
        XCTAssertNil(model.defaultPastWindowKey)
        XCTAssertNil(model.overlaySeries)
    }

    func testCodexHistoryComparisonModelBackfillsPastWindowsFromWeeklyHistory() throws {
        let currentReset = 1_800_604_800
        let pastReset = currentReset - 604_800
        let pastStart = pastReset - 604_800
        let history = CodexUsageWeeklyHistory(samples: [
            Self.weeklySample(recordedAt: pastStart + 60 * 60, remainingPercent: 93, resetsAt: pastReset),
            Self.weeklySample(recordedAt: pastStart + 86_400 + 120, remainingPercent: 82, resetsAt: pastReset),
            Self.weeklySample(recordedAt: pastReset - 60, remainingPercent: 27, resetsAt: pastReset + 1),
            Self.weeklySample(recordedAt: currentReset - 2 * 86_400, remainingPercent: 100, resetsAt: currentReset)
        ])

        let model = try XCTUnwrap(CodexUsageHistoryComparisonModel(
            history: history,
            resetWindowHistory: .empty,
            weeklyWindow: Self.weeklyWindow(remainingPercent: 87, resetsAt: currentReset),
            currentReport: Self.report(fiveHourUsedPercent: 12, weeklyUsedPercent: 13, weeklyResetsAt: currentReset),
            currentTimestamp: currentReset - 60,
            calendar: Self.utcCalendar
        ))

        XCTAssertEqual(model.pastWindows.map(\.key.resetsAt), [pastReset])
        XCTAssertEqual(model.defaultPastWindowKey?.resetsAt, pastReset)
        XCTAssertEqual(model.overlaySeries?.finalUsageMarker.usedPercent, 73)
        XCTAssertEqual(model.resetWindowHistory.records.first?.source, .backfill)
    }

    func testCodexHistoryComparisonModelUsesLatestResetStartAsCurrentWindow() throws {
        let durationSeconds = 10_080 * 60
        let june25ResetStart = Self.timestamp(year: 2026, month: 6, day: 25, hour: 6, minute: 28)
        let june25Reset = june25ResetStart + durationSeconds
        let june28ResetStart = Self.timestamp(year: 2026, month: 6, day: 28, hour: 22, minute: 52)
        let june28Reset = june28ResetStart + durationSeconds
        let june29ResetStart = Self.timestamp(year: 2026, month: 6, day: 29, hour: 9, minute: 39)
        let june29Reset = june29ResetStart + durationSeconds
        let currentSample = Self.weeklySample(
            recordedAt: june29ResetStart + 5 * 60,
            remainingPercent: 99,
            resetsAt: june29Reset
        )
        let history = CodexUsageWeeklyHistory(samples: [
            Self.weeklySample(recordedAt: june25ResetStart + 6 * 60 * 60, remainingPercent: 97, resetsAt: june25Reset),
            Self.weeklySample(recordedAt: june25ResetStart + 86_400, remainingPercent: 85, resetsAt: june25Reset + 73 * 60),
            Self.weeklySample(recordedAt: june28ResetStart - 60, remainingPercent: 33, resetsAt: june25Reset),
            Self.weeklySample(recordedAt: june28ResetStart + 60, remainingPercent: 100, resetsAt: june28Reset),
            Self.weeklySample(recordedAt: june29ResetStart - 60, remainingPercent: 98, resetsAt: june28Reset),
            currentSample
        ])

        let model = try XCTUnwrap(CodexUsageHistoryComparisonModel(
            history: history,
            resetWindowHistory: .empty,
            weeklyWindow: Self.weeklyWindow(remainingPercent: 99, resetsAt: june29Reset),
            currentReport: Self.report(fiveHourUsedPercent: 12, weeklyUsedPercent: 1, weeklyResetsAt: june29Reset),
            currentTimestamp: currentSample.recordedAt,
            calendar: Self.utcCalendar
        ))

        XCTAssertEqual(model.currentChart.resetStartAt, june29ResetStart)
        XCTAssertEqual(model.currentChart.actualSampleCount, 1)
        XCTAssertEqual(model.currentChart.points.first?.recordedAt, june29ResetStart)
        XCTAssertEqual(model.currentChart.latestActualPoint?.recordedAt, currentSample.recordedAt)
        XCTAssertEqual(model.pastWindows.map(\.resetStartAt), [june28ResetStart, june25ResetStart])
        XCTAssertEqual(model.overlaySeries?.resetStartMarker.recordedAt, june28ResetStart)
        XCTAssertEqual(model.overlaySeries?.finalUsageMarker.recordedAt, june29ResetStart - 60)
        XCTAssertLessThan(try XCTUnwrap(model.overlaySeries?.finalUsageMarker.timelinePosition), 1)
        let june28Window = try XCTUnwrap(model.pastWindows.first)
        let june25Window = try XCTUnwrap(model.pastWindows.last)
        XCTAssertEqual(model.displayEndAt(for: june28Window), june29ResetStart)
        XCTAssertEqual(model.displayEndAt(for: june25Window), june28ResetStart)
        XCTAssertEqual(
            CodexUsageHistoryTimelineLabel.windowLabel(
                for: june28Window,
                endingAt: model.displayEndAt(for: june28Window),
                calendar: Self.utcCalendar
            ),
            "6/28-6/29"
        )
        XCTAssertEqual(
            CodexUsageHistoryTimelineLabel.windowLabel(
                for: june25Window,
                endingAt: model.displayEndAt(for: june25Window),
                calendar: Self.utcCalendar
            ),
            "6/25-6/28"
        )
    }

    func testCodexHistoryComparisonModelDropsTransientRollingResetRecords() throws {
        let durationSeconds = 10_080 * 60
        let firstResetStart = Self.timestamp(year: 2026, month: 6, day: 30, hour: 10)
        let firstReset = firstResetStart + durationSeconds
        let secondResetStart = Self.timestamp(year: 2026, month: 7, day: 7, hour: 11)
        let falseRollingStart = Self.timestamp(year: 2026, month: 7, day: 8, hour: 12)
        let currentResetStart = Self.timestamp(year: 2026, month: 7, day: 10, hour: 7)
        let currentReset = currentResetStart + durationSeconds
        let stableSecondStart = secondResetStart + 60 * 60
        let weeklyHistory = CodexUsageWeeklyHistory(samples: [
            Self.weeklySample(recordedAt: firstResetStart + 60 * 60, remainingPercent: 80, resetsAt: firstReset),
            Self.weeklySample(recordedAt: secondResetStart - 60, remainingPercent: 6, resetsAt: firstReset),
            Self.weeklySample(
                recordedAt: secondResetStart + 60,
                remainingPercent: 100,
                resetsAt: secondResetStart + durationSeconds
            ),
            Self.weeklySample(
                recordedAt: secondResetStart + 6 * 60,
                remainingPercent: 100,
                resetsAt: secondResetStart + 5 * 60 + durationSeconds
            ),
            Self.weeklySample(
                recordedAt: secondResetStart + 11 * 60,
                remainingPercent: 100,
                resetsAt: secondResetStart + 10 * 60 + durationSeconds
            ),
            Self.weeklySample(
                recordedAt: secondResetStart + 60 * 60,
                remainingPercent: 99,
                resetsAt: stableSecondStart + durationSeconds
            ),
            Self.weeklySample(
                recordedAt: falseRollingStart - 60,
                remainingPercent: 91,
                resetsAt: stableSecondStart + durationSeconds
            ),
            Self.weeklySample(
                recordedAt: falseRollingStart + 60,
                remainingPercent: 100,
                resetsAt: falseRollingStart + durationSeconds
            ),
            Self.weeklySample(
                recordedAt: falseRollingStart + 2 * 60,
                remainingPercent: 90,
                resetsAt: falseRollingStart + durationSeconds
            ),
            Self.weeklySample(
                recordedAt: falseRollingStart + 3 * 60,
                remainingPercent: 90,
                resetsAt: stableSecondStart + durationSeconds
            ),
            Self.weeklySample(
                recordedAt: currentResetStart - 60,
                remainingPercent: 52,
                resetsAt: stableSecondStart + durationSeconds
            ),
            Self.weeklySample(recordedAt: currentResetStart + 60, remainingPercent: 96, resetsAt: currentReset),
            Self.weeklySample(recordedAt: currentResetStart + 6 * 60, remainingPercent: 95, resetsAt: currentReset)
        ])
        let existingHistory = CodexUsageResetWindowHistory(records: [
            CodexUsageResetWindowHistoryRecord(
                generatedAt: falseRollingStart + 60,
                limitId: "codex",
                windowDurationMins: 10_080,
                resetsAt: falseRollingStart + durationSeconds,
                dailyEndSamples: [],
                finalUsedPercent: 0,
                finalRemainingPercent: 100,
                sampleCount: 1,
                source: .liveCache
            )
        ])

        let model = try XCTUnwrap(CodexUsageHistoryComparisonModel(
            history: weeklyHistory,
            resetWindowHistory: existingHistory,
            weeklyWindow: Self.weeklyWindow(remainingPercent: 95, resetsAt: currentReset),
            currentReport: Self.report(fiveHourUsedPercent: 2, weeklyUsedPercent: 5, weeklyResetsAt: currentReset),
            currentTimestamp: currentResetStart + 6 * 60,
            calendar: Self.utcCalendar
        ))

        XCTAssertEqual(model.pastWindows.map(\.resetStartAt), [secondResetStart, firstResetStart])
        XCTAssertFalse(model.pastWindows.contains { $0.resetStartAt == falseRollingStart })
        XCTAssertEqual(
            model.pastWindows.map {
                CodexUsageHistoryTimelineLabel.windowLabel(
                    for: $0,
                    endingAt: model.displayEndAt(for: $0),
                    calendar: Self.utcCalendar
                )
            },
            ["7/7-7/10", "6/30-7/7"]
        )
    }

    func testCodexHistoryMarkerLabelShowsSevenDayEndUsage() throws {
        let recordedAt = Self.timestamp(year: 2026, month: 6, day: 25, hour: 6, minute: 28)
        let marker = CodexUsageResetWindowOverlayMarker(
            id: "codex-7",
            kind: .sevenDayEnd,
            day: 7,
            recordedAt: recordedAt,
            usedPercent: 74,
            remainingPercent: 26
        )

        XCTAssertEqual(
            CodexUsageHistoryMarkerLabel.hoverText(for: marker, calendar: Self.utcCalendar),
            "6/25 목 종료 · 26%"
        )
    }

    func testCodexHistoryPastTimelineLabelsUseActualDates() throws {
        let resetStart = Self.timestamp(year: 2026, month: 6, day: 18, hour: 6, minute: 28)
        let resetsAt = Self.timestamp(year: 2026, month: 6, day: 25, hour: 6, minute: 28)
        let record = CodexUsageResetWindowHistoryRecord(
            generatedAt: resetsAt - 60,
            limitId: "codex",
            windowDurationMins: 10_080,
            resetsAt: resetsAt,
            dailyEndSamples: [
                CodexUsageResetWindowDailySample(
                    dayIndex: 1,
                    recordedAt: resetStart + 86_400,
                    usedPercent: 20,
                    remainingPercent: 80
                )
            ],
            finalUsedPercent: 77,
            finalRemainingPercent: 23,
            sampleCount: 2,
            source: .backfill
        )
        let series = CodexUsageResetWindowOverlayBuilder().series(for: record)
        let window = CodexUsageResetWindowOverlayWindow(record: record)
        let firstDayMarker = try XCTUnwrap(series.dayEndMarkers.first)

        XCTAssertEqual(
            CodexUsageHistoryTimelineLabel.startLabel(for: series, calendar: Self.utcCalendar),
            "초기화 6/18 목 06:28"
        )
        XCTAssertEqual(
            CodexUsageHistoryTimelineLabel.endLabel(for: series, calendar: Self.utcCalendar),
            "리셋 전 6/25 목"
        )
        XCTAssertEqual(
            CodexUsageHistoryTimelineLabel.windowLabel(for: window, calendar: Self.utcCalendar),
            "6/18-6/25"
        )
        XCTAssertEqual(
            CodexUsageHistoryTimelineLabel.endLabel(
                for: series,
                endingAt: resetStart + 3 * 86_400,
                calendar: Self.utcCalendar
            ),
            "리셋 전 6/21 일"
        )
        XCTAssertEqual(
            CodexUsageHistoryMarkerLabel.hoverText(for: firstDayMarker, calendar: Self.utcCalendar),
            "6/19 금 종료 · 80%"
        )
    }

    func testCodexHistoryModeLabelsDescribeComparisonIntent() {
        XCTAssertEqual(CodexUsageHistoryGraphMode.current.label, "현재")
        XCTAssertEqual(CodexUsageHistoryGraphMode.past.label, "지난")
        XCTAssertEqual(CodexUsageHistoryGraphMode.overlay.label, "비교")
    }

    func testSystemMetricsUpdateReplacesPrivilegedHelperInstallSnapshot() {
        let state = UsageMonitorState(report: nil, cacheSnapshot: nil, errorMessage: nil)
        let snapshot = PrivilegedHelperInstallSnapshot(helperToolExists: true, launchDaemonExists: true)
        let history = SystemMetricsHistory(samples: [
            SystemMetricsHistorySample(capturedAt: Date(timeIntervalSince1970: 1), cpuLoadPercent: 42, memoryUsedPercent: 55)
        ])

        let updated = state.withSystemMetrics(
            .unavailable,
            systemMetricsHistory: history,
            sleepPreventionStatus: .disabled,
            sleepPreventionTriggerStatus: .disabled,
            privilegedHelperInstallSnapshot: snapshot
        )

        XCTAssertEqual(updated.privilegedHelperInstallSnapshot, snapshot)
        XCTAssertEqual(updated.systemMetricsHistory, history)
    }

    func testSystemMetricsUpdatePreservesFiveHourUsageHistory() throws {
        let history = CodexUsageFiveHourHistory(samples: [
            try XCTUnwrap(CodexUsageFiveHourHistorySample(
                recordedAt: 1_000,
                windowDurationMins: 300,
                usedPercent: 24,
                resetsAt: 1_000 + 18_000
            ))
        ])
        let state = UsageMonitorState(
            report: nil,
            cacheSnapshot: nil,
            fiveHourUsageHistory: history,
            errorMessage: nil
        )

        let updated = state.withSystemMetrics(
            .unavailable,
            sleepPreventionStatus: .disabled,
            sleepPreventionTriggerStatus: .disabled,
            privilegedHelperInstallSnapshot: .missing
        )

        XCTAssertEqual(updated.fiveHourUsageHistory, history)
    }

    func testEmptyStateDoesNotCaptureSystemMetrics() {
        let empty = UsageMonitorState.empty

        XCTAssertNil(empty.systemMetrics.cpuLoadPercent)
        XCTAssertNil(empty.systemMetrics.memoryUsedPercent)
        XCTAssertNil(empty.systemMetrics.networkReceivedRateBytesPerSecond)
        XCTAssertFalse(empty.systemMetrics.battery.isPresent)
    }

    func testSystemMetricsHistoryKeepsMostRecentSamples() {
        let start = Date(timeIntervalSince1970: 100)
        let totalSamples = SystemMetricsHistory.defaultMaxSamples + 5
        let history = (0..<totalSamples).reduce(SystemMetricsHistory.empty) { history, index in
            history.appending(
                Self.systemMetricsSnapshot(
                    capturedAt: start.addingTimeInterval(Double(index)),
                    cpuLoadPercent: Double(index),
                    memoryUsedPercent: Double(index + 10)
                )
            )
        }

        XCTAssertEqual(history.samples.count, SystemMetricsHistory.defaultMaxSamples)
        XCTAssertEqual(history.cpuLoadPercents.first, 5)
        XCTAssertEqual(history.cpuLoadPercents.last, Double(totalSamples - 1))
        XCTAssertEqual(history.memoryUsedPercents.first, 15)
        XCTAssertEqual(history.memoryUsedPercents.last, Double(totalSamples + 9))
    }

    func testSystemMetricsHistoryKeepsThreeMinuteTrendAtOneSecondCadence() {
        XCTAssertEqual(SystemMetricsHistory.defaultMaxSamples, 180)
    }

    func testSparklineScaleUsesAbsolutePercentScale() {
        let scale = SparklineScale(values: [49.0, 49.6])

        XCTAssertEqual(SparklineScale.lowerBound, 0, accuracy: 0.001)
        XCTAssertEqual(SparklineScale.upperBound, 100, accuracy: 0.001)
        XCTAssertEqual(scale.normalized(49.0), 0.49, accuracy: 0.001)
        XCTAssertEqual(scale.normalized(49.6), 0.496, accuracy: 0.001)
    }

    func testSparklineScaleKeepsWidePercentRangesStable() {
        let scale = SparklineScale(values: [0, 45, 100])

        XCTAssertEqual(SparklineScale.lowerBound, 0, accuracy: 0.001)
        XCTAssertEqual(SparklineScale.upperBound, 100, accuracy: 0.001)
        XCTAssertEqual(scale.normalized(45), 0.45, accuracy: 0.001)
    }

    func testWeeklyHistoryChartAnchorsResetAtHundredPercentAndMapsSamplesAcrossWeek() throws {
        let start = 1_800_000_000
        let reset = start + 604_800
        let history = CodexUsageWeeklyHistory(samples: [
            Self.weeklySample(recordedAt: start + 302_400, remainingPercent: 63, resetsAt: reset)
        ])
        let chart = WeeklyRemainingHistoryChart(
            history: history,
            weeklyWindow: Self.weeklyWindow(remainingPercent: 63, resetsAt: reset),
            calendar: Self.utcCalendar
        )

        XCTAssertEqual(chart.points.count, 2)
        XCTAssertEqual(chart.dayGridPositions.count, 8)
        XCTAssertEqual(chart.dayGridPositions.first, 0)
        XCTAssertEqual(chart.dayGridPositions.last, 1)
        XCTAssertEqual(chart.dayMarkers.count, 1)
        XCTAssertEqual(chart.points.first?.isResetAnchor, true)
        XCTAssertEqual(try XCTUnwrap(chart.points.first?.xPosition), 0, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(chart.points.first?.yPosition), 1, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(chart.latestActualPoint?.xPosition), 0.5, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(chart.latestActualPoint?.yPosition), 0.63, accuracy: 0.001)
        XCTAssertEqual(chart.summaryText, "63% 남음")
    }

    func testWeeklyHistoryChartShowsActualResetWeekdaysOnTimeline() throws {
        let calendar = Self.utcCalendar
        let resetDate = try XCTUnwrap(calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: 8,
            hour: 0,
            minute: 0
        )))
        let reset = Int(resetDate.timeIntervalSince1970)
        let chart = WeeklyRemainingHistoryChart(
            history: .empty,
            weeklyWindow: Self.weeklyWindow(remainingPercent: 94, resetsAt: reset),
            calendar: calendar
        )

        XCTAssertEqual(chart.resetStartLabel, "6/1 월")
        XCTAssertEqual(chart.resetEndLabel, "6/8 월")
    }

    func testWeeklyHistoryChartKeepsLastSampleForEachDayMarker() throws {
        let calendar = Self.utcCalendar
        let startDate = try XCTUnwrap(calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: 1,
            hour: 0,
            minute: 0
        )))
        let start = Int(startDate.timeIntervalSince1970)
        let reset = start + 604_800
        let history = CodexUsageWeeklyHistory(samples: [
            Self.weeklySample(recordedAt: start + 3_600, remainingPercent: 95, resetsAt: reset),
            Self.weeklySample(recordedAt: start + 82_800, remainingPercent: 88, resetsAt: reset),
            Self.weeklySample(recordedAt: start + 90_000, remainingPercent: 70, resetsAt: reset),
            Self.weeklySample(recordedAt: start + 560_000, remainingPercent: 41, resetsAt: reset)
        ])
        let chart = WeeklyRemainingHistoryChart(
            history: history,
            weeklyWindow: Self.weeklyWindow(remainingPercent: 41, resetsAt: reset),
            calendar: calendar
        )

        XCTAssertEqual(chart.dayMarkers.map(\.id), [0, 1, 6])
        XCTAssertEqual(chart.dayMarkers.map { UsageMonitorState.percent($0.point.remainingPercent) }, ["88", "70", "41"])
        XCTAssertEqual(chart.dayMarkers.first?.hoverLabel, "6/1 월 · 88%")
        XCTAssertEqual(chart.dayMarkers.last?.hoverLabel, "6/7 일 · 41%")
    }

    func testWeeklyHistoryChartFiltersPreviousResetWindow() {
        let start = 1_800_000_000
        let reset = start + 604_800
        let history = CodexUsageWeeklyHistory(samples: [
            Self.weeklySample(recordedAt: start - 120, remainingPercent: 20, resetsAt: reset - 604_800),
            Self.weeklySample(recordedAt: start + 60, remainingPercent: 99, resetsAt: reset)
        ])
        let chart = WeeklyRemainingHistoryChart(
            history: history,
            weeklyWindow: Self.weeklyWindow(remainingPercent: 99, resetsAt: reset)
        )

        XCTAssertEqual(chart.actualSampleCount, 1)
        XCTAssertEqual(chart.latestActualPoint?.remainingPercent, 99)
    }

    func testWeeklyHistoryChartKeepsSamplesWhenResetTimestampJittersBySeconds() {
        let start = 1_800_000_000
        let stableReset = start + 604_800
        let currentReset = stableReset - 1
        let history = CodexUsageWeeklyHistory(samples: [
            Self.weeklySample(recordedAt: start + 86_400 - 120, remainingPercent: 90, resetsAt: stableReset),
            Self.weeklySample(recordedAt: start + 2 * 86_400 - 120, remainingPercent: 80, resetsAt: stableReset),
            Self.weeklySample(recordedAt: start + 3 * 86_400 - 120, remainingPercent: 64, resetsAt: stableReset)
        ])
        let currentSample = Self.weeklySample(
            recordedAt: start + 3 * 86_400 + 120,
            remainingPercent: 63,
            resetsAt: currentReset
        )

        let chart = WeeklyRemainingHistoryChart(
            history: history,
            weeklyWindow: Self.weeklyWindow(remainingPercent: 63, resetsAt: currentReset),
            currentSample: currentSample
        )

        XCTAssertEqual(chart.actualSampleCount, 4)
        XCTAssertEqual(chart.latestActualPoint?.remainingPercent, 63)
        XCTAssertEqual(
            chart.dayMarkers.map { UsageMonitorState.percent($0.point.remainingPercent) },
            ["90", "80", "64", "63"]
        )
    }

    func testWeeklyHistoryChartKeepsSamplesWhenResetTimestampRollsWithinSameStartWindow() {
        let start = 1_800_000_000
        let stableReset = start + 604_800
        let currentReset = stableReset + 73 * 60
        let history = CodexUsageWeeklyHistory(samples: [
            Self.weeklySample(recordedAt: start + 86_400 - 120, remainingPercent: 90, resetsAt: stableReset),
            Self.weeklySample(recordedAt: start + 2 * 86_400 - 120, remainingPercent: 80, resetsAt: stableReset + 30 * 60),
            Self.weeklySample(recordedAt: start + 3 * 86_400 - 120, remainingPercent: 64, resetsAt: stableReset + 60 * 60)
        ])
        let currentSample = Self.weeklySample(
            recordedAt: start + 3 * 86_400 + 120,
            remainingPercent: 63,
            resetsAt: currentReset
        )

        let chart = WeeklyRemainingHistoryChart(
            history: history,
            weeklyWindow: Self.weeklyWindow(remainingPercent: 63, resetsAt: currentReset),
            currentSample: currentSample
        )

        XCTAssertEqual(chart.resetStartAt, start)
        XCTAssertEqual(chart.actualSampleCount, 4)
        XCTAssertEqual(chart.latestActualPoint?.remainingPercent, 63)
        XCTAssertEqual(
            chart.dayMarkers.map { UsageMonitorState.percent($0.point.remainingPercent) },
            ["90", "80", "64", "63"]
        )
    }

    func testWeeklyHistoryChartStartsNewTimelineWhenResetTimestampChanges() throws {
        let calendar = Self.utcCalendar
        let oldStartDate = try XCTUnwrap(calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: 1,
            hour: 0
        )))
        let oldStart = Int(oldStartDate.timeIntervalSince1970)
        let oldReset = oldStart + 604_800
        let newStart = oldStart + 2 * 86_400
        let newReset = newStart + 604_800
        let currentSample = Self.weeklySample(recordedAt: newStart + 3_600, remainingPercent: 99, resetsAt: newReset)
        let history = CodexUsageWeeklyHistory(samples: [
            Self.weeklySample(recordedAt: oldStart + 86_400, remainingPercent: 82, resetsAt: oldReset),
            Self.weeklySample(recordedAt: oldStart + 2 * 86_400 - 60, remainingPercent: 74, resetsAt: oldReset)
        ])

        let chart = WeeklyRemainingHistoryChart(
            history: history,
            weeklyWindow: Self.weeklyWindow(remainingPercent: 99, resetsAt: newReset),
            currentSample: currentSample,
            calendar: calendar
        )

        XCTAssertEqual(chart.resetStartAt, newStart)
        XCTAssertEqual(chart.actualSampleCount, 1)
        XCTAssertEqual(chart.points.first?.recordedAt, newStart)
        XCTAssertEqual(chart.points.first?.remainingPercent, 100)
        XCTAssertEqual(chart.points.first?.xPosition, 0)
        XCTAssertEqual(chart.latestActualPoint?.remainingPercent, 99)
        XCTAssertEqual(chart.dayMarkers.map(\.hoverLabel), ["6/3 수 · 99%"])
        XCTAssertFalse(chart.points.contains { $0.recordedAt < newStart })
    }

    func testWeeklyHistoryChartDoesNotDrawUpwardRemainingSegmentsWithinSameResetWindow() {
        let start = 1_800_000_000
        let reset = start + 604_800
        let currentSample = Self.weeklySample(recordedAt: start + 18_000, remainingPercent: 85, resetsAt: reset)
        let history = CodexUsageWeeklyHistory(samples: [
            Self.weeklySample(recordedAt: start + 3_600, remainingPercent: 93, resetsAt: reset),
            Self.weeklySample(recordedAt: start + 7_200, remainingPercent: 88, resetsAt: reset),
            Self.weeklySample(recordedAt: start + 10_800, remainingPercent: 91, resetsAt: reset),
            Self.weeklySample(recordedAt: start + 14_400, remainingPercent: 80, resetsAt: reset)
        ])

        let chart = WeeklyRemainingHistoryChart(
            history: history,
            weeklyWindow: Self.weeklyWindow(remainingPercent: 85, resetsAt: reset),
            currentSample: currentSample
        )

        XCTAssertEqual(
            chart.points.map { UsageMonitorState.percent($0.remainingPercent) },
            ["100", "93", "88", "88", "80", "80"]
        )
        XCTAssertEqual(chart.latestActualPoint?.remainingPercent, 80)
        XCTAssertTrue(
            zip(chart.points, chart.points.dropFirst()).allSatisfy { previous, next in
                next.remainingPercent <= previous.remainingPercent
            },
            "Weekly remaining graph should never rise inside one reset window"
        )
    }

    func testWeeklyHistoryChartUsesCurrentSampleBeforePersistedHistoryCatchesUp() throws {
        let start = 1_800_000_000
        let reset = start + 604_800
        let currentSample = Self.weeklySample(recordedAt: start + 151_200, remainingPercent: 82, resetsAt: reset)

        let chart = WeeklyRemainingHistoryChart(
            history: .empty,
            weeklyWindow: Self.weeklyWindow(remainingPercent: 82, resetsAt: reset),
            currentSample: currentSample
        )

        XCTAssertEqual(chart.actualSampleCount, 1)
        XCTAssertEqual(try XCTUnwrap(chart.latestActualPoint?.xPosition), 0.25, accuracy: 0.001)
        XCTAssertEqual(chart.latestActualPoint?.remainingPercent, 82)
    }

    func testWeeklyHistoryChartShowsCompletedAndCurrentDayMarkers() throws {
        let calendar = Self.utcCalendar
        let startDate = try XCTUnwrap(calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: 1,
            hour: 0,
            minute: 0
        )))
        let start = Int(startDate.timeIntervalSince1970)
        let reset = start + 604_800
        let currentSample = Self.weeklySample(recordedAt: start + 2 * 86_400 + 10 * 3_600, remainingPercent: 66, resetsAt: reset)
        let history = CodexUsageWeeklyHistory(samples: [
            Self.weeklySample(recordedAt: start + 8 * 3_600, remainingPercent: 93, resetsAt: reset),
            Self.weeklySample(recordedAt: start + 23 * 3_600 + 50 * 60, remainingPercent: 88, resetsAt: reset),
            Self.weeklySample(recordedAt: start + 86_400 + 20 * 3_600, remainingPercent: 74, resetsAt: reset),
            Self.weeklySample(recordedAt: start + 2 * 86_400 + 9 * 3_600, remainingPercent: 68, resetsAt: reset)
        ])

        let chart = WeeklyRemainingHistoryChart(
            history: history,
            weeklyWindow: Self.weeklyWindow(remainingPercent: 66, resetsAt: reset),
            currentSample: currentSample,
            calendar: calendar
        )

        XCTAssertEqual(chart.dayMarkers.map(\.id), [0, 1, 2])
        XCTAssertEqual(chart.dayMarkers.map { UsageMonitorState.percent($0.point.remainingPercent) }, ["88", "74", "66"])
        XCTAssertEqual(chart.dayMarkers.first?.hoverLabel, "6/1 월 종료 · 88%")
        XCTAssertEqual(chart.dayMarkers[1].hoverLabel, "6/2 화 종료 · 74%")
        XCTAssertEqual(chart.dayMarkers.last?.hoverLabel, "6/3 수 · 66%")
        XCTAssertEqual(chart.latestActualPoint?.remainingPercent, 66)
    }

    func testWeeklyHistoryChartCarriesForwardCompletedDayMarkersAcrossResetBoundary() throws {
        let calendar = Self.utcCalendar
        let startDate = try XCTUnwrap(calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 6,
            day: 1,
            hour: 0,
            minute: 21,
            second: 23
        )))
        let start = Int(startDate.timeIntervalSince1970)
        let reset = start + 604_800
        let history = CodexUsageWeeklyHistory(samples: [
            Self.weeklySample(recordedAt: start + 86_400 + 18 * 3_600, remainingPercent: 87, resetsAt: reset),
            Self.weeklySample(recordedAt: start + 2 * 86_400 - 5 * 60, remainingPercent: 83, resetsAt: reset),
            Self.weeklySample(recordedAt: start + 2 * 86_400 + 17 * 3_600, remainingPercent: 64, resetsAt: reset)
        ])
        let currentSample = Self.weeklySample(
            recordedAt: start + 2 * 86_400 + 17 * 3_600 + 2 * 60,
            remainingPercent: 64,
            resetsAt: reset
        )

        let chart = WeeklyRemainingHistoryChart(
            history: history,
            weeklyWindow: Self.weeklyWindow(remainingPercent: 64, resetsAt: reset),
            currentSample: currentSample,
            calendar: calendar
        )

        XCTAssertEqual(chart.dayMarkers.map(\.id), [0, 1, 2])
        XCTAssertEqual(chart.dayMarkers.map(\.hoverLabel), ["6/1 월 종료 · 100%", "6/2 화 종료 · 83%", "6/3 수 · 64%"])
        XCTAssertEqual(chart.recordingStartLabel, "기록 시작 6/2 화 18:21")
        XCTAssertEqual(chart.timelineStartDisplayLabel, "초기화 6/1 월 00:21")
        XCTAssertEqual(chart.dayMarkers[0].point.recordedAt, start + 86_400)
        XCTAssertEqual(chart.dayMarkers[1].point.recordedAt, start + 2 * 86_400)
        XCTAssertEqual(chart.dayMarkers[2].point.recordedAt, currentSample.recordedAt)
        XCTAssertEqual(try XCTUnwrap(chart.dayMarkers[0].point.xPosition), 1.0 / 7.0, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(chart.dayMarkers[1].point.xPosition), 2.0 / 7.0, accuracy: 0.001)
        XCTAssertEqual(chart.latestActualPoint?.remainingPercent, 64)
        XCTAssertEqual(chart.points.last, chart.latestActualPoint)
        XCTAssertEqual(chart.points.map(\.xPosition), chart.points.map(\.xPosition).sorted())
        XCTAssertFalse(chart.points.contains { $0.recordedAt > currentSample.recordedAt })
    }

    func testWeeklyHistoryChartStartsAtHundredPercentWithoutExtendingPastCurrentSample() {
        let start = 1_800_000_000
        let reset = start + 604_800
        let currentSample = Self.weeklySample(recordedAt: start + 2 * 86_400 + 10 * 3_600, remainingPercent: 66, resetsAt: reset)

        let chart = WeeklyRemainingHistoryChart(
            history: .empty,
            weeklyWindow: Self.weeklyWindow(remainingPercent: 66, resetsAt: reset),
            currentSample: currentSample
        )

        XCTAssertEqual(chart.points.first?.isResetAnchor, true)
        XCTAssertEqual(chart.points.first?.remainingPercent, 100)
        XCTAssertEqual(chart.points.last, chart.latestActualPoint)
        XCTAssertEqual(chart.points.last?.remainingPercent, 66)
        XCTAssertFalse(chart.points.contains { $0.recordedAt > currentSample.recordedAt })
    }

    func testWeeklyHistoryHoverLabelAvoidsCurrentPercentLabelWhenMarkersAreClose() {
        let size = CGSize(width: 244, height: 74)
        let mondayMarker = CGPoint(x: 36, y: 12)
        let currentMarker = CGPoint(x: 70, y: 12)
        let currentLabel = WeeklyRemainingHistoryLabelPlacement.valueLabelPosition(
            for: currentMarker,
            in: size
        )
        let hoverLabel = WeeklyRemainingHistoryLabelPlacement.hoverLabelPosition(
            for: mondayMarker,
            avoiding: currentLabel,
            in: size
        )

        let currentRect = WeeklyRemainingHistoryLabelPlacement.labelRect(
            center: currentLabel,
            size: WeeklyRemainingHistoryLabelPlacement.valueLabelSize
        )
        let hoverRect = WeeklyRemainingHistoryLabelPlacement.labelRect(
            center: hoverLabel,
            size: WeeklyRemainingHistoryLabelPlacement.hoverLabelSize
        )

        XCTAssertFalse(
            hoverRect.intersects(currentRect.insetBy(dx: -4, dy: -3)),
            "Hover tooltip should not cover the current percent label for adjacent weekday markers"
        )
    }

    func testWeeklyHistoryHoverSelectsDayColumnNotMarkerDot() {
        let size = CGSize(width: 244, height: 74)
        let dayGrid = (0...7).map { Double($0) / 7 }
        let saturday = WeeklyRemainingHistoryDayMarker(
            id: 0,
            point: WeeklyRemainingHistoryPoint(
                recordedAt: 1_786_762_203 + 86_400,
                remainingPercent: 25,
                xPosition: 1.0 / 7.0,
                isResetAnchor: false
            ),
            hoverLabel: "8/15 토 종료 · 25%"
        )
        let sunday = WeeklyRemainingHistoryDayMarker(
            id: 1,
            point: WeeklyRemainingHistoryPoint(
                recordedAt: 1_786_762_203 + 98_010,
                remainingPercent: 25,
                xPosition: 98_010.0 / 604_800.0,
                isResetAnchor: false
            ),
            hoverLabel: "8/16 일 · 25%"
        )

        XCTAssertEqual(
            WeeklyRemainingHistoryInteraction.nearestMarkerID(
                to: CGPoint(x: size.width * 0.05, y: size.height * 0.5),
                markers: [saturday, sunday],
                in: size,
                dayGridPositions: dayGrid
            ),
            0
        )
        XCTAssertEqual(
            WeeklyRemainingHistoryInteraction.nearestMarkerID(
                to: CGPoint(x: size.width * 0.20, y: size.height * 0.5),
                markers: [saturday, sunday],
                in: size,
                dayGridPositions: dayGrid
            ),
            1
        )
        XCTAssertEqual(
            WeeklyRemainingHistoryInteraction.nearestMarkerID(
                to: CGPoint(x: size.width / 7, y: size.height * 0.5),
                markers: [saturday, sunday],
                in: size,
                dayGridPositions: dayGrid
            ),
            0,
            "Completed Saturday marker sits on the first grid line and belongs to Saturday"
        )
        XCTAssertEqual(
            WeeklyRemainingHistoryInteraction.nearestMarkerID(
                to: CGPoint(x: -8, y: size.height * 0.5),
                markers: [saturday, sunday],
                in: size,
                dayGridPositions: dayGrid
            ),
            0
        )
        XCTAssertEqual(
            WeeklyRemainingHistoryInteraction.hoverAnchor(
                for: saturday,
                dayGridPositions: dayGrid,
                in: size
            ).x,
            size.width / 14,
            accuracy: 0.01
        )
        XCTAssertEqual(
            WeeklyRemainingHistoryInteraction.dayColumns(dayGridPositions: dayGrid).map(\.id),
            [0, 1, 2, 3, 4, 5, 6]
        )
    }

    func testGrokWeeklyDayLabelsFollowResetStartWeekday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600) ?? .current
        let start = 1_786_762_203
        let reset = start + 604_800
        let sample = Self.weeklySample(
            recordedAt: start + 98_010,
            remainingPercent: 25,
            resetsAt: reset
        )
        let chart = WeeklyRemainingHistoryChart(
            history: CodexUsageWeeklyHistory(samples: [sample]),
            weeklyWindow: Self.weeklyWindow(remainingPercent: 25, resetsAt: reset),
            currentSample: sample,
            calendar: calendar
        )

        XCTAssertTrue(chart.dayMarkers.contains { $0.id == 0 && $0.hoverLabel.contains("토") })
        XCTAssertTrue(chart.dayMarkers.contains { $0.id == 1 && $0.hoverLabel.contains("일") })
    }

    func testWeeklyHistoryLineIncludesCurrentMarkerPoint() {
        let start = 1_800_000_000
        let reset = start + 604_800
        let currentSample = Self.weeklySample(
            recordedAt: start + 4 * 86_400 + 12 * 3_600,
            remainingPercent: 58,
            resetsAt: reset
        )
        let history = CodexUsageWeeklyHistory(samples: [
            Self.weeklySample(recordedAt: start + 2 * 86_400, remainingPercent: 83, resetsAt: reset),
            Self.weeklySample(recordedAt: start + 3 * 86_400, remainingPercent: 74, resetsAt: reset),
            currentSample
        ])

        let chart = WeeklyRemainingHistoryChart(
            history: history,
            weeklyWindow: Self.weeklyWindow(remainingPercent: 58, resetsAt: reset),
            currentSample: currentSample
        )

        XCTAssertEqual(chart.points.last, chart.latestActualPoint)
        XCTAssertEqual(chart.points.last?.recordedAt, currentSample.recordedAt)
        XCTAssertEqual(chart.points.last?.remainingPercent, 58)
    }

    func testMacResourcesTabStaysUnscrollableWithTrendGraphs() {
        XCTAssertFalse(MacDogPopoverModule.codex.usesScrollableContent)
        XCTAssertFalse(MacDogPopoverModule.mac.usesScrollableContent)
        XCTAssertFalse(MacDogPopoverModule.sleep.usesScrollableContent)
        XCTAssertFalse(MacDogPopoverModule.battery.usesScrollableContent)
        XCTAssertTrue(MacDogPopoverModule.settings.usesScrollableContent)
        XCTAssertEqual(CodexUsagePanelLayout.sectionSpacing, 3)
        XCTAssertEqual(CodexUsagePanelLayout.weeklyGraphHeight, 56)
        XCTAssertEqual(CodexUsagePanelLayout.weeklyOnlyGraphHeight, 89)
        XCTAssertEqual(CodexUsagePanelLayout.weeklyGraphHeight(fiveHourIsAvailable: true), 56)
        XCTAssertEqual(CodexUsagePanelLayout.weeklyGraphHeight(fiveHourIsAvailable: false), 89)
        XCTAssertEqual(CodexUsagePanelLayout.weeklyGraphYAxisWidth, 28)
        XCTAssertEqual(CodexUsagePanelLayout.weeklyGraphAxisSpacing, 5)
        XCTAssertEqual(
            CodexUsagePanelLayout.weeklyGraphPlotStartX,
            CodexUsagePanelLayout.weeklyGraphYAxisWidth + CodexUsagePanelLayout.weeklyGraphAxisSpacing
        )
        XCTAssertEqual(CodexUsagePanelLayout.weeklyGraphTimelineHeight, 10)
        XCTAssertGreaterThan(MacResourcesPanelLayout.sparklineHeight, 0)
        XCTAssertLessThanOrEqual(
            MacResourcesPanelLayout.estimatedContentHeight,
            MacDogPopoverLayout.nonScrollableContentHeight
        )
    }

    func testWeeklyTimelineStartLabelStaysInsideGraphBounds() {
        let totalWidth = MacDogPopoverLayout.contentSurfaceSize.width - (MacDogPopoverLayout.contentPadding * 2)
        let startLabelWidth = WeeklyRemainingTimelineLabelLayout.startLabelWidth(totalWidth: totalWidth)

        XCTAssertGreaterThan(startLabelWidth, 150)
        XCTAssertLessThanOrEqual(
            WeeklyRemainingTimelineLabelLayout.leadingInset +
                startLabelWidth +
                WeeklyRemainingTimelineLabelLayout.labelSpacing +
                WeeklyRemainingTimelineLabelLayout.endLabelWidth,
            totalWidth
        )
    }

    func testDemoDataProvidesCpuAndMemoryTrendSamplesForMacTab() {
        let state = MacDogDemoData.state()

        XCTAssertGreaterThan(state.systemMetricsHistory.cpuLoadPercents.count, 1)
        XCTAssertGreaterThan(state.systemMetricsHistory.memoryUsedPercents.count, 1)
        XCTAssertEqual(state.systemMetricsHistory.cpuLoadPercents.last, state.systemMetrics.cpuLoadPercent)
        XCTAssertEqual(state.systemMetricsHistory.memoryUsedPercents.last, state.systemMetrics.memoryUsedPercent)
    }

    func testDemoDataProvidesWeeklyUsageHistoryForCodexTab() {
        let state = MacDogDemoData.state(now: MacDogDemoData.readmeScreenshotTimestamp)
        let chart = WeeklyRemainingHistoryChart(
            history: state.weeklyUsageHistory,
            weeklyWindow: state.codexLimit?.weekly,
            calendar: Self.utcCalendar
        )

        XCTAssertGreaterThan(chart.actualSampleCount, 1)
        XCTAssertEqual(chart.latestActualPoint?.remainingPercent, state.codexLimit?.weekly?.remainingPercent)
        XCTAssertEqual(chart.resetStartLabel, "6/1 월")
        XCTAssertEqual(chart.resetEndLabel, "6/8 월")
    }

    func testDemoDataProvidesResetCreditExpiriesForCodexTab() throws {
        let state = MacDogDemoData.state(now: MacDogDemoData.readmeScreenshotTimestamp)
        let resetCredits = try XCTUnwrap(state.report?.resetCredits)
        let fiveHour = try XCTUnwrap(state.codexLimit?.fiveHour)

        XCTAssertEqual(resetCredits.availableCount, 3)
        XCTAssertEqual(resetCredits.credits.count, 3)
        XCTAssertEqual(resetCredits.credits.first?.expiresAt, "2026-07-18T00:34:01Z")
        XCTAssertEqual(fiveHour.usedPercent, 42)
        XCTAssertEqual(fiveHour.remainingPercent, 58)
        XCTAssertEqual(fiveHour.windowDurationMins, 300)
    }

    func testPetReactionPrioritizesSystemLoad() {
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 10, weeklyUsedPercent: 20),
            cacheSnapshot: nil,
            errorMessage: nil,
            systemMetrics: Self.systemMetricsSnapshot(
                capturedAt: Date(timeIntervalSince1970: 100),
                cpuLoadPercent: 88,
                memoryUsedPercent: 40,
                battery: Self.battery(percent: 12, isCharging: false, isConnectedToPower: false)
            )
        )

        XCTAssertEqual(state.petReaction, .systemLoad)
        XCTAssertTrue(state.petReaction.pausesRoaming)
    }

    func testPetReactionUsesLowBatteryOnlyWhenUnplugged() {
        let unplugged = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 10, weeklyUsedPercent: 20),
            cacheSnapshot: nil,
            errorMessage: nil,
            systemMetrics: Self.systemMetricsSnapshot(
                capturedAt: Date(timeIntervalSince1970: 100),
                cpuLoadPercent: 20,
                memoryUsedPercent: 40,
                battery: Self.battery(percent: 18, isCharging: false, isConnectedToPower: false)
            )
        )
        let plugged = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 10, weeklyUsedPercent: 20),
            cacheSnapshot: nil,
            errorMessage: nil,
            systemMetrics: Self.systemMetricsSnapshot(
                capturedAt: Date(timeIntervalSince1970: 100),
                cpuLoadPercent: 20,
                memoryUsedPercent: 40,
                battery: Self.battery(percent: 18, isCharging: false, isConnectedToPower: true)
            )
        )

        XCTAssertEqual(unplugged.petReaction, .lowBattery)
        XCTAssertEqual(plugged.petReaction, .normal)
    }

    func testPetReactionShowsChargingState() {
        let state = UsageMonitorState(
            report: Self.report(fiveHourUsedPercent: 10, weeklyUsedPercent: 20),
            cacheSnapshot: nil,
            errorMessage: nil,
            systemMetrics: Self.systemMetricsSnapshot(
                capturedAt: Date(timeIntervalSince1970: 100),
                cpuLoadPercent: 20,
                memoryUsedPercent: 40,
                battery: Self.battery(percent: 62, isCharging: true, isConnectedToPower: true)
            )
        )

        XCTAssertEqual(state.petReaction, .charging)
        XCTAssertTrue(state.petReaction.pausesRoaming)
    }

    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func report(
        fiveHourUsedPercent: Double?,
        weeklyUsedPercent: Double,
        fiveHourResetsAt: Int? = nil,
        weeklyResetsAt: Int? = nil,
        rateLimitReachedType: String? = nil
    ) -> CodexUsageReport {
        let fiveHour = fiveHourUsedPercent.map {
            UsageWindowReport(
                kind: .fiveHour,
                usedPercent: $0,
                remainingPercent: 100 - $0,
                windowDurationMins: 300,
                resetsAt: fiveHourResetsAt
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
            rateLimitReachedType: rateLimitReachedType
        )
        return CodexUsageReport(
            generatedAt: 0,
            source: "test",
            planType: "pro",
            credits: nil,
            rateLimitReachedType: rateLimitReachedType,
            limits: ["codex": limit]
        )
    }

    private static func incompleteCodexReport() -> CodexUsageReport {
        let limit = UsageLimitReport(
            limitId: "codex",
            limitName: "Codex",
            primary: UsageWindowReport(
                kind: .other,
                usedPercent: 0,
                remainingPercent: 100,
                windowDurationMins: nil,
                resetsAt: nil
            ),
            secondary: nil,
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

    private static func claudePreview(
        observedAt: Int,
        usedPercent: Double
    ) -> ClaudeUsagePreviewState {
        let usage = ClaudeStatusLineSnapshot(
            observedAt: observedAt,
            fiveHour: try! ClaudeUsageWindowSnapshot(
                usedPercent: usedPercent,
                resetsAt: observedAt + 3_600
            ),
            sevenDay: try! ClaudeUsageWindowSnapshot(
                usedPercent: max(0, usedPercent - 10),
                resetsAt: observedAt + 86_400
            )
        )
        return ClaudeUsagePreviewState(
            isEnabled: true,
            cacheSnapshot: ClaudeUsageCacheSnapshot(
                lastEventAt: observedAt,
                lastUsageObservedAt: observedAt,
                staleAfterSeconds: 900,
                usage: usage,
                issue: nil
            ),
            history: .empty,
            loadIssue: nil
        )
    }

    private static func cacheSnapshot(
        cachedAt: Int,
        staleAfterSeconds: Int = 120,
        report: CodexUsageReport?,
        error: CodexUsageCacheError? = nil
    ) -> CodexUsageCacheSnapshot {
        CodexUsageCacheSnapshot(
            cachedAt: cachedAt,
            staleAfterSeconds: staleAfterSeconds,
            report: report,
            error: error
        )
    }

    private static func weeklyWindow(
        remainingPercent: Double,
        resetsAt: Int
    ) -> UsageWindowReport {
        UsageWindowReport(
            kind: .weekly,
            usedPercent: 100 - remainingPercent,
            remainingPercent: remainingPercent,
            windowDurationMins: 10_080,
            resetsAt: resetsAt
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

    private static func timestamp(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0
    ) -> Int {
        let date = utcCalendar.date(from: DateComponents(
            timeZone: TimeZone(secondsFromGMT: 0),
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
        return Int(date.timeIntervalSince1970)
    }

    private static func resetWindowRecord(
        resetsAt: Int,
        finalUsedPercent: Double
    ) -> CodexUsageResetWindowHistoryRecord {
        CodexUsageResetWindowHistoryRecord(
            generatedAt: resetsAt - 60,
            limitId: "codex",
            windowDurationMins: 10_080,
            resetsAt: resetsAt,
            dailyEndSamples: [
                CodexUsageResetWindowDailySample(
                    dayIndex: 7,
                    recordedAt: resetsAt,
                    usedPercent: finalUsedPercent,
                    remainingPercent: 100 - finalUsedPercent
                )
            ],
            finalUsedPercent: finalUsedPercent,
            finalRemainingPercent: 100 - finalUsedPercent,
            sampleCount: 1,
            source: .liveCache
        )
    }

    private static func systemMetricsSnapshot(
        capturedAt: Date,
        cpuLoadPercent: Double,
        memoryUsedPercent: Double,
        battery: BatteryStatusSnapshot = .unavailable
    ) -> SystemMetricsSnapshot {
        SystemMetricsSnapshot(
            capturedAt: capturedAt,
            cpuLoadPercent: cpuLoadPercent,
            memoryUsedPercent: memoryUsedPercent,
            memoryDetails: nil,
            diskUsedPercent: nil,
            diskDetails: nil,
            networkReceivedBytes: nil,
            networkSentBytes: nil,
            networkReceivedRateBytesPerSecond: nil,
            networkSentRateBytesPerSecond: nil,
            activeInterfaceCount: 0,
            primaryNetworkInterfaceName: nil,
            localIPAddress: nil,
            cpuBreakdown: nil,
            battery: battery,
            chargeLimitSupport: .unavailable
        )
    }

    private static func battery(
        percent: Int,
        isCharging: Bool,
        isConnectedToPower: Bool
    ) -> BatteryStatusSnapshot {
        BatteryStatusSnapshot(
            isPresent: true,
            percent: percent,
            isCharging: isCharging,
            isCharged: false,
            isConnectedToPower: isConnectedToPower,
            timeToFullChargeMinutes: nil,
            timeToEmptyMinutes: nil,
            cycleCount: nil,
            temperatureCelsius: nil
        )
    }
}
