import XCTest
@testable import MacDog

final class UsageProviderSelectionTests: XCTestCase {
    func testNormalizedMissingMaskEnablesOnlyStoredVisibleMain() {
        XCTAssertEqual(
            UsageProviderSelection.normalized(enabledRaw: nil, main: .codex, detailGraphVisible: nil),
            UsageProviderSelection(enabled: .codex, main: .codex, detailGraphVisible: true)
        )
        XCTAssertEqual(
            UsageProviderSelection.normalized(enabledRaw: nil, main: .grok, detailGraphVisible: false),
            UsageProviderSelection(enabled: .grok, main: .grok, detailGraphVisible: false)
        )
    }

    func testNormalizedEmptyOrUnknownMaskBecomesCodexOnly() {
        XCTAssertEqual(
            UsageProviderSelection.normalized(enabledRaw: 0, main: .grok, detailGraphVisible: true),
            UsageProviderSelection(enabled: .codex, main: .codex, detailGraphVisible: true)
        )
        XCTAssertEqual(
            UsageProviderSelection.normalized(enabledRaw: 1 << 5, main: .grok, detailGraphVisible: true),
            UsageProviderSelection(enabled: .codex, main: .codex, detailGraphVisible: true)
        )
    }

    func testNormalizedStripsUnknownBitsAndKeepsVisibleProviders() {
        let bothAndUnknown = UsageProviderMask.codex.rawValue
            | UsageProviderMask.grok.rawValue
            | (1 << 5)
        let selection = UsageProviderSelection.normalized(
            enabledRaw: bothAndUnknown,
            main: .grok,
            detailGraphVisible: true
        )

        XCTAssertEqual(selection.enabled, [.codex, .grok])
        XCTAssertEqual(selection.main, .grok)
        XCTAssertFalse(selection.enabled.contains(UsageProviderMask(rawValue: 1 << 5)))
    }

    func testNormalizedPromotesMainWhenMissingFromEnabledSet() {
        XCTAssertEqual(
            UsageProviderSelection.normalized(
                enabledRaw: UsageProviderMask.grok.rawValue,
                main: .codex,
                detailGraphVisible: true
            ).main,
            .grok
        )
        XCTAssertEqual(
            UsageProviderSelection.normalized(
                enabledRaw: UsageProviderMask.codex.rawValue | UsageProviderMask.grok.rawValue,
                main: nil,
                detailGraphVisible: true
            ).main,
            .codex
        )
    }

    func testNormalizedNeverPlacesClaudeInEnabledSetOrMain() {
        let selection = UsageProviderSelection.normalized(
            enabledRaw: nil,
            main: .claude,
            detailGraphVisible: true
        )

        XCTAssertEqual(selection.enabled, .codex)
        XCTAssertEqual(selection.main, .codex)
        XCTAssertNotEqual(selection.main, .claude)
        XCTAssertEqual(UsageProviderMask.claude.rawValue, 1 << 2)
        XCTAssertFalse(selection.enabled.contains(.claude))
    }

    func testNormalizedIsIdempotent() {
        let inputs: [(Int?, UsageProviderMode?, Bool?)] = [
            (nil, .codex, nil),
            (nil, .grok, false),
            (0, .grok, true),
            (1 << 5, .codex, true),
            (UsageProviderMask.grok.rawValue, .codex, true),
            (
                UsageProviderMask.codex.rawValue | UsageProviderMask.grok.rawValue | (1 << 4),
                .grok,
                false
            )
        ]

        for (enabledRaw, main, graphVisible) in inputs {
            let first = UsageProviderSelection.normalized(
                enabledRaw: enabledRaw,
                main: main,
                detailGraphVisible: graphVisible
            )
            let second = UsageProviderSelection.normalized(
                enabledRaw: first.enabled.rawValue,
                main: first.main,
                detailGraphVisible: first.detailGraphVisible
            )
            XCTAssertEqual(first, second)
        }
    }

    func testOnlyEnabledProviderCannotBeTurnedOffAndMainPickerShowsForDual() {
        let codexOnly = UsageProviderSelection(enabled: .codex, main: .codex, detailGraphVisible: true)
        let dual = UsageProviderSelection(enabled: [.codex, .grok], main: .grok, detailGraphVisible: false)

        XCTAssertTrue(codexOnly.isOnlyEnabled(.codex))
        XCTAssertFalse(codexOnly.isOnlyEnabled(.grok))
        XCTAssertFalse(codexOnly.showsMainPicker)
        XCTAssertFalse(dual.isOnlyEnabled(.codex))
        XCTAssertFalse(dual.isOnlyEnabled(.grok))
        XCTAssertTrue(dual.showsMainPicker)
        XCTAssertEqual(codexOnly.disabling(.codex), codexOnly)
    }

    func testDisablingLastVisibleProviderIsRejected() {
        let codexOnly = UsageProviderSelection.normalized(
            enabledRaw: UsageProviderMask.codex.rawValue,
            main: .codex,
            detailGraphVisible: true
        )
        let grokOnly = UsageProviderSelection.normalized(
            enabledRaw: UsageProviderMask.grok.rawValue,
            main: .grok,
            detailGraphVisible: false
        )

        XCTAssertEqual(codexOnly.disabling(.codex), codexOnly)
        XCTAssertEqual(grokOnly.disabling(.grok), grokOnly)
    }

    func testDisablingMainPromotesRemainingCodexThenGrok() {
        let bothCodexMain = UsageProviderSelection.normalized(
            enabledRaw: UsageProviderMask.codex.rawValue | UsageProviderMask.grok.rawValue,
            main: .codex,
            detailGraphVisible: true
        )
        let bothGrokMain = UsageProviderSelection.normalized(
            enabledRaw: UsageProviderMask.codex.rawValue | UsageProviderMask.grok.rawValue,
            main: .grok,
            detailGraphVisible: true
        )

        XCTAssertEqual(
            bothCodexMain.disabling(.codex),
            UsageProviderSelection(enabled: .grok, main: .grok, detailGraphVisible: true)
        )
        XCTAssertEqual(
            bothGrokMain.disabling(.grok),
            UsageProviderSelection(enabled: .codex, main: .codex, detailGraphVisible: true)
        )
    }

    func testEnablingAddsProviderWithoutChangingMain() {
        let codexOnly = UsageProviderSelection.normalized(
            enabledRaw: UsageProviderMask.codex.rawValue,
            main: .codex,
            detailGraphVisible: true
        )

        XCTAssertEqual(
            codexOnly.enabling(.grok),
            UsageProviderSelection(enabled: [.codex, .grok], main: .codex, detailGraphVisible: true)
        )
        XCTAssertEqual(
            codexOnly.enabling(.claude),
            UsageProviderSelection(enabled: [.codex, .claude], main: .codex, detailGraphVisible: true)
        )
    }

    func testSettingMainEnablesProviderIfNeeded() {
        let codexOnly = UsageProviderSelection.normalized(
            enabledRaw: UsageProviderMask.codex.rawValue,
            main: .codex,
            detailGraphVisible: false
        )

        XCTAssertEqual(
            codexOnly.settingMain(.grok),
            UsageProviderSelection(enabled: [.codex, .grok], main: .grok, detailGraphVisible: false)
        )
        XCTAssertEqual(
            codexOnly.settingMain(.claude),
            UsageProviderSelection(enabled: [.codex, .claude], main: .claude, detailGraphVisible: false)
        )
    }

    func testSettingDetailGraphVisibleDoesNotChangeEnabledOrMain() {
        let selection = UsageProviderSelection.normalized(
            enabledRaw: UsageProviderMask.codex.rawValue | UsageProviderMask.grok.rawValue,
            main: .grok,
            detailGraphVisible: true
        )

        XCTAssertEqual(
            selection.settingDetailGraphVisible(false),
            UsageProviderSelection(enabled: [.codex, .grok], main: .grok, detailGraphVisible: false)
        )
    }

    func testMissingMaskMigratesExistingCodexOrGrokModeAndPersistsNormalizedKeys() throws {
        try withDefaults { defaults in
            defaults.set("grok", forKey: RunnerPreferences.usageProviderModeKey)
            RunnerPreferences.migrateUsageProviderMode(defaults: defaults)
            RunnerPreferences.migrateUsageProviderMode(defaults: defaults)

            XCTAssertEqual(RunnerPreferences.usageProviderMode(defaults: defaults), .grok)
            XCTAssertEqual(
                RunnerPreferences.usageProviderSelection(defaults: defaults),
                UsageProviderSelection(enabled: .grok, main: .grok, detailGraphVisible: true)
            )
            XCTAssertEqual(
                defaults.integer(forKey: RunnerPreferences.usageEnabledProviderMaskKey),
                UsageProviderMask.grok.rawValue
            )
            XCTAssertEqual(
                defaults.bool(forKey: RunnerPreferences.usageDetailGraphVisibleKey),
                true
            )
        }
    }

    func testRegisterDefaultsMigratesMissingModeToCodexOnlySelection() throws {
        try withDefaults { defaults in
            RunnerPreferences.registerDefaults(defaults: defaults)

            XCTAssertEqual(RunnerPreferences(defaults: defaults).usageProviderMode, .codex)
            XCTAssertEqual(
                RunnerPreferences(defaults: defaults).usageProviderSelection,
                UsageProviderSelection(enabled: .codex, main: .codex, detailGraphVisible: true)
            )
        }
    }

    func testEmptyMaskMigratesToCodexEvenWhenStoredMainIsGrok() throws {
        try withDefaults { defaults in
            defaults.set("grok", forKey: RunnerPreferences.usageProviderModeKey)
            defaults.set(0, forKey: RunnerPreferences.usageEnabledProviderMaskKey)
            RunnerPreferences.migrateUsageProviderMode(defaults: defaults)
            RunnerPreferences.migrateUsageProviderMode(defaults: defaults)

            XCTAssertEqual(RunnerPreferences.usageProviderMode(defaults: defaults), .codex)
            XCTAssertEqual(
                RunnerPreferences.usageProviderSelection(defaults: defaults),
                UsageProviderSelection(enabled: .codex, main: .codex, detailGraphVisible: true)
            )
        }
    }

    func testStoredClaudeModeWithoutTheBitMigratesToCodexAndIgnoresHiddenReenable() throws {
        try withDefaults { defaults in
            defaults.set("claude", forKey: RunnerPreferences.usageProviderModeKey)
            RunnerPreferences.setClaudeUsageProviderReenabled(true, defaults: defaults)
            RunnerPreferences.migrateUsageProviderMode(defaults: defaults)
            RunnerPreferences.migrateUsageProviderMode(defaults: defaults)

            XCTAssertEqual(RunnerPreferences.usageProviderMode(defaults: defaults), .codex)
            XCTAssertEqual(defaults.string(forKey: RunnerPreferences.usageProviderModeKey), "codex")
            let selection = RunnerPreferences.usageProviderSelection(defaults: defaults)
            XCTAssertEqual(selection.enabled, .codex)
            XCTAssertEqual(selection.main, .codex)
            XCTAssertFalse(selection.enabled.contains(.claude))
            XCTAssertEqual(
                defaults.integer(forKey: RunnerPreferences.usageEnabledProviderMaskKey),
                UsageProviderMask.codex.rawValue
            )
        }
    }

    func testClaudeBitInTheMaskSurvivesRepeatedMigration() throws {
        try withDefaults { defaults in
            let selection = UsageProviderSelection(
                enabled: [.codex, .claude],
                main: .claude,
                detailGraphVisible: false
            )
            RunnerPreferences.setUsageProviderSelection(selection, defaults: defaults)
            RunnerPreferences.setClaudeUsageProviderReenabled(false, defaults: defaults)
            RunnerPreferences.migrateUsageProviderMode(defaults: defaults)
            RunnerPreferences.migrateUsageProviderMode(defaults: defaults)

            XCTAssertEqual(RunnerPreferences.usageProviderMode(defaults: defaults), .claude)
            XCTAssertEqual(RunnerPreferences.usageProviderSelection(defaults: defaults), selection)
            XCTAssertTrue(selection.enabled.contains(.claude))
        }
    }

    func testSetUsageProviderModeWritesExclusiveVisibleSelection() throws {
        try withDefaults { defaults in
            RunnerPreferences.setUsageProviderSelection(
                UsageProviderSelection(enabled: [.codex, .grok], main: .codex, detailGraphVisible: false),
                defaults: defaults
            )
            RunnerPreferences.setUsageProviderMode(.grok, defaults: defaults)

            XCTAssertEqual(RunnerPreferences.usageProviderMode(defaults: defaults), .grok)
            XCTAssertEqual(
                RunnerPreferences.usageProviderSelection(defaults: defaults),
                UsageProviderSelection(enabled: .grok, main: .grok, detailGraphVisible: false)
            )
        }
    }

    func testPersistedDualSelectionSurvivesReloadAndDoesNotChangeAfterSecondMigrate() throws {
        try withDefaults { defaults in
            let dual = UsageProviderSelection(
                enabled: [.codex, .grok],
                main: .grok,
                detailGraphVisible: false
            )
            RunnerPreferences.setUsageProviderSelection(dual, defaults: defaults)
            RunnerPreferences.migrateUsageProviderMode(defaults: defaults)
            RunnerPreferences.migrateUsageProviderMode(defaults: defaults)

            XCTAssertEqual(RunnerPreferences(defaults: defaults).usageProviderMode, .grok)
            XCTAssertEqual(RunnerPreferences(defaults: defaults).usageProviderSelection, dual)
        }
    }

    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let suiteName = "UsageProviderSelectionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try body(defaults)
    }
}
