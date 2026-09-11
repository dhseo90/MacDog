import XCTest
@testable import MacDog

final class UsageProviderWorkDiffTests: XCTestCase {
    private let codexOnly = UsageProviderSelection(
        enabled: .codex,
        main: .codex,
        detailGraphVisible: true
    )
    private let grokOnly = UsageProviderSelection(
        enabled: .grok,
        main: .grok,
        detailGraphVisible: true
    )
    private let dualCodexMain = UsageProviderSelection(
        enabled: [.codex, .grok],
        main: .codex,
        detailGraphVisible: true
    )
    private let dualGrokMain = UsageProviderSelection(
        enabled: [.codex, .grok],
        main: .grok,
        detailGraphVisible: true
    )
    private let dualGraphHidden = UsageProviderSelection(
        enabled: [.codex, .grok],
        main: .codex,
        detailGraphVisible: false
    )

    func testUnchangedSelectionCancelsNothing() {
        XCTAssertEqual(
            UsageProviderWorkDiff.make(
                previousMode: .codex,
                previousSelection: dualCodexMain,
                currentMode: .codex,
                currentSelection: dualCodexMain
            ),
            .none
        )
    }

    func testDisablingCodexCancelsOnlyCodexRefreshAndSyncsAgents() {
        let diff = UsageProviderWorkDiff.make(
            previousMode: .codex,
            previousSelection: dualCodexMain,
            currentMode: .grok,
            currentSelection: grokOnly
        )

        XCTAssertTrue(diff.cancelNotifications)
        XCTAssertTrue(diff.cancelCodexRefresh)
        XCTAssertFalse(diff.cancelGrokRefresh)
        XCTAssertTrue(diff.synchronizeCacheAgents)
    }

    func testDisablingGrokCancelsOnlyGrokRefreshAndKeepsCodexTask() {
        let diff = UsageProviderWorkDiff.make(
            previousMode: .codex,
            previousSelection: dualCodexMain,
            currentMode: .codex,
            currentSelection: codexOnly
        )

        XCTAssertFalse(diff.cancelNotifications)
        XCTAssertFalse(diff.cancelCodexRefresh)
        XCTAssertTrue(diff.cancelGrokRefresh)
        XCTAssertTrue(diff.synchronizeCacheAgents)
    }

    func testSwitchingMainWhileBothEnabledCancelsNotificationsWithoutTouchingRefresh() {
        let diff = UsageProviderWorkDiff.make(
            previousMode: .codex,
            previousSelection: dualCodexMain,
            currentMode: .grok,
            currentSelection: dualGrokMain
        )

        XCTAssertTrue(diff.cancelNotifications)
        XCTAssertFalse(diff.cancelCodexRefresh)
        XCTAssertFalse(diff.cancelGrokRefresh)
        XCTAssertFalse(diff.synchronizeCacheAgents)
    }

    func testEnablingSecondProviderSyncsAgentsWithoutCancellingTheRunningRefresh() {
        let diff = UsageProviderWorkDiff.make(
            previousMode: .grok,
            previousSelection: grokOnly,
            currentMode: .grok,
            currentSelection: dualGrokMain
        )

        XCTAssertFalse(diff.cancelNotifications)
        XCTAssertFalse(diff.cancelCodexRefresh)
        XCTAssertFalse(diff.cancelGrokRefresh)
        XCTAssertTrue(diff.synchronizeCacheAgents)
    }

    func testGraphVisibilityOnlyDoesNotCancelWorkOrSyncAgents() {
        XCTAssertEqual(
            UsageProviderWorkDiff.make(
                previousMode: .codex,
                previousSelection: dualCodexMain,
                currentMode: .codex,
                currentSelection: dualGraphHidden
            ),
            .none
        )
    }

    func testSingleCodexToSingleGrokCancelsCodexRefreshAndNotifications() {
        let diff = UsageProviderWorkDiff.make(
            previousMode: .codex,
            previousSelection: codexOnly,
            currentMode: .grok,
            currentSelection: grokOnly
        )

        XCTAssertTrue(diff.cancelNotifications)
        XCTAssertTrue(diff.cancelCodexRefresh)
        XCTAssertFalse(diff.cancelGrokRefresh)
        XCTAssertTrue(diff.synchronizeCacheAgents)
    }

    func testClaudeSwitchCancelsAllProviderWork() {
        let diff = UsageProviderWorkDiff.make(
            previousMode: .codex,
            previousSelection: dualCodexMain,
            currentMode: .claude,
            currentSelection: dualCodexMain
        )

        XCTAssertTrue(diff.cancelNotifications)
        XCTAssertTrue(diff.cancelCodexRefresh)
        XCTAssertTrue(diff.cancelGrokRefresh)
        XCTAssertTrue(diff.synchronizeCacheAgents)
    }

    func testLeavingClaudeCancelsAllProviderWork() {
        let diff = UsageProviderWorkDiff.make(
            previousMode: .claude,
            previousSelection: codexOnly,
            currentMode: .codex,
            currentSelection: dualCodexMain
        )

        XCTAssertTrue(diff.cancelNotifications)
        XCTAssertTrue(diff.cancelCodexRefresh)
        XCTAssertTrue(diff.cancelGrokRefresh)
        XCTAssertTrue(diff.synchronizeCacheAgents)
    }

    func testStayingOnClaudeDoesNotCancelVisibleProviderWork() {
        XCTAssertEqual(
            UsageProviderWorkDiff.make(
                previousMode: .claude,
                previousSelection: dualCodexMain,
                currentMode: .claude,
                currentSelection: dualGrokMain
            ),
            .none
        )
    }
}
