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
        XCTAssertEqual(preferences.sleepPreventionControlMode, .time)
        XCTAssertTrue(preferences.sleepPreventionEnabled)
        XCTAssertEqual(preferences.sleepPreventionSessionPreset, .indefinite)
        XCTAssertNil(preferences.sleepPreventionEndsAt)
        XCTAssertFalse(preferences.sleepPreventionPowerAdapterTriggerEnabled)
        XCTAssertFalse(preferences.sleepPreventionCodexAppTriggerEnabled)
        XCTAssertFalse(preferences.sleepPreventionChargingBelowThresholdTriggerEnabled)
        XCTAssertFalse(preferences.sleepPreventionCPUThresholdTriggerEnabled)
        XCTAssertFalse(preferences.sleepPreventionMemoryThresholdTriggerEnabled)
        XCTAssertFalse(preferences.sleepPreventionNetworkActivityTriggerEnabled)
        XCTAssertFalse(preferences.sleepPreventionExternalVolumeTriggerEnabled)
    }

    func testChargingModeUsesPowerAdapterTriggerOnly() {
        RunnerPreferences.setSleepPreventionMode(.charging, defaults: defaults)

        let preferences = RunnerPreferences(defaults: defaults)
        XCTAssertEqual(preferences.sleepPreventionMode, .charging)
        XCTAssertEqual(preferences.sleepPreventionControlMode, .condition)
        XCTAssertFalse(preferences.sleepPreventionEnabled)
        XCTAssertTrue(preferences.sleepPreventionPowerAdapterTriggerEnabled)
        XCTAssertFalse(preferences.sleepPreventionCodexAppTriggerEnabled)
        XCTAssertFalse(preferences.sleepPreventionChargingBelowThresholdTriggerEnabled)
        XCTAssertFalse(preferences.sleepPreventionCPUThresholdTriggerEnabled)
        XCTAssertFalse(preferences.sleepPreventionMemoryThresholdTriggerEnabled)
        XCTAssertFalse(preferences.sleepPreventionNetworkActivityTriggerEnabled)
        XCTAssertFalse(preferences.sleepPreventionExternalVolumeTriggerEnabled)
    }

    func testTimedModeDefaultsToOneHourWhenNoTimedPresetExists() {
        RunnerPreferences.setSleepPreventionMode(.timed, defaults: defaults)

        let preferences = RunnerPreferences(defaults: defaults)
        XCTAssertEqual(preferences.sleepPreventionMode, .timed)
        XCTAssertEqual(preferences.sleepPreventionControlMode, .time)
        XCTAssertTrue(preferences.sleepPreventionEnabled)
        XCTAssertEqual(preferences.sleepPreventionSessionPreset, .oneHour)
        XCTAssertNotNil(preferences.sleepPreventionEndsAt)
        XCTAssertFalse(preferences.sleepPreventionPowerAdapterTriggerEnabled)
        XCTAssertFalse(preferences.sleepPreventionCodexAppTriggerEnabled)
        XCTAssertFalse(preferences.sleepPreventionChargingBelowThresholdTriggerEnabled)
        XCTAssertFalse(preferences.sleepPreventionCPUThresholdTriggerEnabled)
        XCTAssertFalse(preferences.sleepPreventionMemoryThresholdTriggerEnabled)
        XCTAssertFalse(preferences.sleepPreventionNetworkActivityTriggerEnabled)
        XCTAssertFalse(preferences.sleepPreventionExternalVolumeTriggerEnabled)
    }

    func testApplicationModeUsesCodexAppTriggerOnly() {
        RunnerPreferences.setSleepPreventionMode(.application, defaults: defaults)

        let preferences = RunnerPreferences(defaults: defaults)
        XCTAssertEqual(preferences.sleepPreventionMode, .application)
        XCTAssertEqual(preferences.sleepPreventionControlMode, .condition)
        XCTAssertFalse(preferences.sleepPreventionEnabled)
        XCTAssertFalse(preferences.sleepPreventionPowerAdapterTriggerEnabled)
        XCTAssertTrue(preferences.sleepPreventionCodexAppTriggerEnabled)
        XCTAssertFalse(preferences.sleepPreventionChargingBelowThresholdTriggerEnabled)
        XCTAssertFalse(preferences.sleepPreventionCPUThresholdTriggerEnabled)
        XCTAssertFalse(preferences.sleepPreventionMemoryThresholdTriggerEnabled)
        XCTAssertFalse(preferences.sleepPreventionNetworkActivityTriggerEnabled)
        XCTAssertFalse(preferences.sleepPreventionExternalVolumeTriggerEnabled)
    }

    func testOffModeClearsManualAndTriggerModes() {
        RunnerPreferences.setSleepPreventionMode(.always, defaults: defaults)
        RunnerPreferences.setSleepPreventionPowerAdapterTrigger(true, defaults: defaults)
        RunnerPreferences.setSleepPreventionCodexAppTrigger(true, defaults: defaults)
        RunnerPreferences.setSleepPreventionChargingBelowThresholdTrigger(true, defaults: defaults)
        RunnerPreferences.setSleepPreventionCPUThresholdTrigger(true, defaults: defaults)
        RunnerPreferences.setSleepPreventionMemoryThresholdTrigger(true, defaults: defaults)
        RunnerPreferences.setSleepPreventionNetworkActivityTrigger(true, defaults: defaults)
        RunnerPreferences.setSleepPreventionExternalVolumeTrigger(true, defaults: defaults)

        RunnerPreferences.setSleepPreventionMode(.off, defaults: defaults)

        let preferences = RunnerPreferences(defaults: defaults)
        XCTAssertEqual(preferences.sleepPreventionMode, .off)
        XCTAssertEqual(preferences.sleepPreventionControlMode, .off)
        XCTAssertFalse(preferences.sleepPreventionEnabled)
        XCTAssertNil(preferences.sleepPreventionEndsAt)
        XCTAssertFalse(preferences.sleepPreventionPowerAdapterTriggerEnabled)
        XCTAssertFalse(preferences.sleepPreventionCodexAppTriggerEnabled)
        XCTAssertFalse(preferences.sleepPreventionChargingBelowThresholdTriggerEnabled)
        XCTAssertFalse(preferences.sleepPreventionCPUThresholdTriggerEnabled)
        XCTAssertFalse(preferences.sleepPreventionMemoryThresholdTriggerEnabled)
        XCTAssertFalse(preferences.sleepPreventionNetworkActivityTriggerEnabled)
        XCTAssertFalse(preferences.sleepPreventionExternalVolumeTriggerEnabled)
    }

    func testAutomaticTriggerSettingsPersistAcrossPreferenceReads() {
        RunnerPreferences.setSleepPreventionMode(.charging, defaults: defaults)
        RunnerPreferences.setSleepPreventionCPUThresholdTrigger(true, defaults: defaults)
        RunnerPreferences.setSleepPreventionMemoryThresholdTrigger(true, defaults: defaults)
        RunnerPreferences.setSleepPreventionNetworkActivityTrigger(true, defaults: defaults)
        RunnerPreferences.setSleepPreventionBatteryThresholdPercent(70, defaults: defaults)
        RunnerPreferences.setSleepPreventionCPUThresholdPercent(65, defaults: defaults)
        RunnerPreferences.setSleepPreventionMemoryThresholdPercent(72, defaults: defaults)
        RunnerPreferences.setSleepPreventionNetworkThresholdKBPerSecond(256, defaults: defaults)
        RunnerPreferences.setSleepPreventionAppMatchText("Xcode", defaults: defaults)
        RunnerPreferences.setSleepPreventionPreventDisplaySleep(false, defaults: defaults)
        RunnerPreferences.setSleepPreventionPreventClosedLidSleep(false, defaults: defaults)
        RunnerPreferences.setSleepPreventionDisableScreenLock(false, defaults: defaults)

        let firstRead = RunnerPreferences(defaults: defaults)
        let secondRead = RunnerPreferences(defaults: defaults)

        XCTAssertEqual(firstRead.sleepPreventionMode, .charging)
        XCTAssertEqual(secondRead.sleepPreventionMode, .charging)
        XCTAssertTrue(secondRead.sleepPreventionPowerAdapterTriggerEnabled)
        XCTAssertTrue(secondRead.sleepPreventionCPUThresholdTriggerEnabled)
        XCTAssertTrue(secondRead.sleepPreventionMemoryThresholdTriggerEnabled)
        XCTAssertTrue(secondRead.sleepPreventionNetworkActivityTriggerEnabled)
        XCTAssertEqual(firstRead.sleepPreventionBatteryThresholdPercent, 70)
        XCTAssertEqual(secondRead.sleepPreventionCPUThresholdPercent, 65)
        XCTAssertEqual(secondRead.sleepPreventionMemoryThresholdPercent, 72)
        XCTAssertEqual(secondRead.sleepPreventionNetworkThresholdKBPerSecond, 256)
        XCTAssertEqual(secondRead.sleepPreventionAppMatchText, "Xcode")
        XCTAssertFalse(secondRead.sleepPreventionPreventDisplaySleep)
        XCTAssertFalse(secondRead.sleepPreventionPreventClosedLidSleep)
        XCTAssertFalse(secondRead.sleepPreventionDisableScreenLock)
        XCTAssertEqual(
            secondRead.sleepPreventionPolicy,
            SleepPreventionPolicy(
                preventDisplaySleep: false,
                preventClosedLidSleep: false,
                disableScreenLock: false
            )
        )
    }

    func testDefaultPreferencesDoNotRequireBackgroundSystemMetrics() {
        let preferences = RunnerPreferences(defaults: defaults)

        XCTAssertFalse(preferences.hasAutomaticSleepPreventionTrigger)
        XCTAssertFalse(preferences.requiresSystemMetricsForSleepPreventionTrigger)
    }

    func testProviderOnlyTriggersDoNotRequireBackgroundSystemMetrics() {
        RunnerPreferences.setSleepPreventionCodexAppTrigger(true, defaults: defaults)
        RunnerPreferences.setSleepPreventionExternalVolumeTrigger(true, defaults: defaults)

        let preferences = RunnerPreferences(defaults: defaults)

        XCTAssertTrue(preferences.hasAutomaticSleepPreventionTrigger)
        XCTAssertFalse(preferences.requiresSystemMetricsForSleepPreventionTrigger)
    }

    func testMetricBasedTriggersRequireBackgroundSystemMetrics() {
        RunnerPreferences.setSleepPreventionPowerAdapterTrigger(true, defaults: defaults)
        var preferences = RunnerPreferences(defaults: defaults)
        XCTAssertTrue(preferences.hasAutomaticSleepPreventionTrigger)
        XCTAssertTrue(preferences.requiresSystemMetricsForSleepPreventionTrigger)

        RunnerPreferences.setSleepPreventionMode(.off, defaults: defaults)
        RunnerPreferences.setSleepPreventionChargingBelowThresholdTrigger(true, defaults: defaults)
        preferences = RunnerPreferences(defaults: defaults)
        XCTAssertTrue(preferences.requiresSystemMetricsForSleepPreventionTrigger)

        RunnerPreferences.setSleepPreventionMode(.off, defaults: defaults)
        RunnerPreferences.setSleepPreventionCPUThresholdTrigger(true, defaults: defaults)
        preferences = RunnerPreferences(defaults: defaults)
        XCTAssertTrue(preferences.requiresSystemMetricsForSleepPreventionTrigger)

        RunnerPreferences.setSleepPreventionMode(.off, defaults: defaults)
        RunnerPreferences.setSleepPreventionMemoryThresholdTrigger(true, defaults: defaults)
        preferences = RunnerPreferences(defaults: defaults)
        XCTAssertTrue(preferences.requiresSystemMetricsForSleepPreventionTrigger)

        RunnerPreferences.setSleepPreventionMode(.off, defaults: defaults)
        RunnerPreferences.setSleepPreventionNetworkActivityTrigger(true, defaults: defaults)
        preferences = RunnerPreferences(defaults: defaults)
        XCTAssertTrue(preferences.requiresSystemMetricsForSleepPreventionTrigger)
    }

    func testLoginLaunchPreferenceDefaultsToEnabledAndPersists() {
        var preferences = RunnerPreferences(defaults: defaults)
        XCTAssertTrue(preferences.loginLaunchEnabled)
        XCTAssertTrue(RunnerPreferences.loginLaunchEnabled(defaults: defaults))

        RunnerPreferences.setLoginLaunchEnabled(false, defaults: defaults)

        preferences = RunnerPreferences(defaults: defaults)
        XCTAssertFalse(preferences.loginLaunchEnabled)
        XCTAssertFalse(RunnerPreferences.loginLaunchEnabled(defaults: defaults))
    }

    func testAutomaticTriggerDetailSettingsClampAndNormalize() {
        RunnerPreferences.setSleepPreventionBatteryThresholdPercent(10, defaults: defaults)
        RunnerPreferences.setSleepPreventionCPUThresholdPercent(105, defaults: defaults)
        RunnerPreferences.setSleepPreventionMemoryThresholdPercent(3, defaults: defaults)
        RunnerPreferences.setSleepPreventionNetworkThresholdKBPerSecond(2_000, defaults: defaults)
        RunnerPreferences.setSleepPreventionAppMatchText("   ", defaults: defaults)

        let preferences = RunnerPreferences(defaults: defaults)

        XCTAssertEqual(preferences.sleepPreventionBatteryThresholdPercent, 10)
        XCTAssertEqual(preferences.sleepPreventionCPUThresholdPercent, 100)
        XCTAssertEqual(preferences.sleepPreventionMemoryThresholdPercent, 10)
        XCTAssertEqual(preferences.sleepPreventionNetworkThresholdKBPerSecond, 1_024)
        XCTAssertEqual(preferences.sleepPreventionAppMatchText, "codex")
    }

    func testTimeAndConditionModesAreMutuallyExclusive() {
        RunnerPreferences.setSleepPreventionMode(.timed, defaults: defaults)
        RunnerPreferences.setSleepPreventionCPUThresholdTrigger(true, defaults: defaults)

        var preferences = RunnerPreferences(defaults: defaults)
        XCTAssertEqual(preferences.sleepPreventionControlMode, .condition)
        XCTAssertFalse(preferences.sleepPreventionEnabled)
        XCTAssertNil(preferences.sleepPreventionEndsAt)
        XCTAssertTrue(preferences.sleepPreventionCPUThresholdTriggerEnabled)

        RunnerPreferences.setSleepPreventionControlMode(.time, defaults: defaults)

        preferences = RunnerPreferences(defaults: defaults)
        XCTAssertEqual(preferences.sleepPreventionControlMode, .time)
        XCTAssertTrue(preferences.sleepPreventionEnabled)
        XCTAssertFalse(preferences.sleepPreventionCPUThresholdTriggerEnabled)
        XCTAssertFalse(preferences.sleepPreventionMemoryThresholdTriggerEnabled)
    }
}
