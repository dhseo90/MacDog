import XCTest
@testable import MacDog

final class SleepPreventionModeTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "MacDogTests.SleepPreventionMode.\(UUID().uuidString)"
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

    func testAlwaysModeEnablesManualIndefiniteSleepPrevention() {
        RunnerPreferences.setSleepPreventionMode(.always, defaults: defaults)

        let preferences = RunnerPreferences(defaults: defaults)
        XCTAssertEqual(preferences.sleepPreventionMode, .always)
        XCTAssertTrue(preferences.sleepPreventionEnabled)
        XCTAssertEqual(preferences.sleepPreventionSessionPreset, .indefinite)
        XCTAssertNil(preferences.sleepPreventionEndsAt)
        XCTAssertFalse(preferences.sleepPreventionPowerAdapterTriggerEnabled)
        XCTAssertFalse(preferences.sleepPreventionCodexAppTriggerEnabled)
    }

    func testChargingModeUsesPowerAdapterTriggerOnly() {
        RunnerPreferences.setSleepPreventionMode(.charging, defaults: defaults)

        let preferences = RunnerPreferences(defaults: defaults)
        XCTAssertEqual(preferences.sleepPreventionMode, .charging)
        XCTAssertFalse(preferences.sleepPreventionEnabled)
        XCTAssertTrue(preferences.sleepPreventionPowerAdapterTriggerEnabled)
        XCTAssertFalse(preferences.sleepPreventionCodexAppTriggerEnabled)
    }

    func testTimedModeDefaultsToOneHourWhenNoTimedPresetExists() {
        RunnerPreferences.setSleepPreventionMode(.timed, defaults: defaults)

        let preferences = RunnerPreferences(defaults: defaults)
        XCTAssertEqual(preferences.sleepPreventionMode, .timed)
        XCTAssertTrue(preferences.sleepPreventionEnabled)
        XCTAssertEqual(preferences.sleepPreventionSessionPreset, .oneHour)
        XCTAssertNotNil(preferences.sleepPreventionEndsAt)
        XCTAssertFalse(preferences.sleepPreventionPowerAdapterTriggerEnabled)
        XCTAssertFalse(preferences.sleepPreventionCodexAppTriggerEnabled)
    }

    func testApplicationModeUsesCodexAppTriggerOnly() {
        RunnerPreferences.setSleepPreventionMode(.application, defaults: defaults)

        let preferences = RunnerPreferences(defaults: defaults)
        XCTAssertEqual(preferences.sleepPreventionMode, .application)
        XCTAssertFalse(preferences.sleepPreventionEnabled)
        XCTAssertFalse(preferences.sleepPreventionPowerAdapterTriggerEnabled)
        XCTAssertTrue(preferences.sleepPreventionCodexAppTriggerEnabled)
    }

    func testOffModeClearsManualAndTriggerModes() {
        RunnerPreferences.setSleepPreventionMode(.always, defaults: defaults)
        RunnerPreferences.setSleepPreventionPowerAdapterTrigger(true, defaults: defaults)
        RunnerPreferences.setSleepPreventionCodexAppTrigger(true, defaults: defaults)

        RunnerPreferences.setSleepPreventionMode(.off, defaults: defaults)

        let preferences = RunnerPreferences(defaults: defaults)
        XCTAssertEqual(preferences.sleepPreventionMode, .off)
        XCTAssertFalse(preferences.sleepPreventionEnabled)
        XCTAssertNil(preferences.sleepPreventionEndsAt)
        XCTAssertFalse(preferences.sleepPreventionPowerAdapterTriggerEnabled)
        XCTAssertFalse(preferences.sleepPreventionCodexAppTriggerEnabled)
    }
}
