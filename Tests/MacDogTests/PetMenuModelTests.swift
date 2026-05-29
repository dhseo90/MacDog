import XCTest
@testable import MacDog

final class PetMenuModelTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "MacDogTests.PetMenuModel.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        RunnerPreferences.registerDefaults(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testMenuBarAndDesktopMenusShareActionsExceptSurfaceSwitch() {
        let preferences = RunnerPreferences(defaults: defaults)
        let menuBar = PetMenuModel(preferences: preferences, surface: .menuBar)
        let desktop = PetMenuModel(preferences: preferences, surface: .desktop)

        XCTAssertEqual(
            actionTitles(excludingSurfaceSwitch: menuBar),
            actionTitles(excludingSurfaceSwitch: desktop)
        )
        XCTAssertTrue(menuBar.commands.contains(PetMenuCommand(title: "데스크톱 펫 보기", action: .showDesktopPet)))
        XCTAssertTrue(desktop.commands.contains(PetMenuCommand(title: "메뉴바로 돌아가기", action: .returnToMenuBar)))
    }

    func testMenuModelReflectsPreferenceStatesAndToggleActions() {
        RunnerPreferences.setDisplayBasis(.weekly, defaults: defaults)
        RunnerPreferences.setReducedMotion(true, defaults: defaults)
        RunnerPreferences.setSleepPreventionMode(.timed, defaults: defaults)
        RunnerPreferences.setSleepPreventionSessionPreset(.thirtyMinutes, defaults: defaults)
        let preferences = RunnerPreferences(defaults: defaults)

        let model = PetMenuModel(preferences: preferences, surface: .menuBar)

        XCTAssertTrue(model.commands.contains(PetMenuCommand(
            title: "주간",
            action: .setDisplayBasis(.weekly),
            isSelected: true
        )))
        XCTAssertTrue(model.commands.contains(PetMenuCommand(
            title: "움직임 줄이기",
            action: .setReducedMotion(false),
            isSelected: true
        )))
        XCTAssertTrue(model.commands.contains(PetMenuCommand(
            title: "30분",
            action: .setSleepPreventionSessionPreset(.thirtyMinutes),
            isSelected: true
        )))
        XCTAssertEqual(submenu(in: model, titled: "시간 기준 길이")?.isEnabled, true)
    }

    func testMenuModelReflectsConditionTriggerToggleActions() {
        RunnerPreferences.setSleepPreventionCPUThresholdTrigger(true, defaults: defaults)
        let preferences = RunnerPreferences(defaults: defaults)

        let model = PetMenuModel(preferences: preferences, surface: .menuBar)

        XCTAssertTrue(model.commands.contains(PetMenuCommand(
            title: "CPU 사용 \(RunnerPreferences.defaultSleepPreventionCPUThresholdPercent)% 이상",
            action: .setSleepPreventionCPUThresholdTrigger(false),
            isSelected: true
        )))
        XCTAssertEqual(submenu(in: model, titled: "시간 기준 길이")?.isEnabled, false)
    }

    func testDurationSubmenuIsDisabledOutsideTimedMode() {
        RunnerPreferences.setSleepPreventionMode(.always, defaults: defaults)
        let preferences = RunnerPreferences(defaults: defaults)

        let model = PetMenuModel(preferences: preferences, surface: .menuBar)

        XCTAssertEqual(submenu(in: model, titled: "시간 기준 길이")?.isEnabled, false)
    }

    func testMenuBarSurfaceReturnsToMenuBarWhenDesktopPetIsAlreadyEnabled() {
        RunnerPreferences.setDesktopPetEnabled(true, defaults: defaults)
        let preferences = RunnerPreferences(defaults: defaults)

        let model = PetMenuModel(preferences: preferences, surface: .menuBar)

        XCTAssertTrue(model.commands.contains(PetMenuCommand(title: "메뉴바로 돌아가기", action: .returnToMenuBar)))
        XCTAssertFalse(model.commands.contains(PetMenuCommand(title: "데스크톱 펫 보기", action: .showDesktopPet)))
    }

    private func actionTitles(excludingSurfaceSwitch model: PetMenuModel) -> [String] {
        model.commands
            .filter { command in
                command.action != .showDesktopPet && command.action != .returnToMenuBar
            }
            .map(\.title)
    }

    private func submenu(in model: PetMenuModel, titled title: String) -> PetMenuSubmenu? {
        model.entries.compactMap { entry in
            if case .submenu(let submenu) = entry, submenu.title == title {
                return submenu
            }
            return nil
        }.first
    }
}
