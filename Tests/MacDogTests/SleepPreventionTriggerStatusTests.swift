import XCTest
@testable import MacDog

final class SleepPreventionTriggerStatusTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "MacDogTests.SleepPreventionTriggerStatus.\(UUID().uuidString)"
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

    func testCPUThresholdTriggerMatchesWhenUsageIsHigh() {
        RunnerPreferences.setSleepPreventionCPUThresholdTrigger(true, defaults: defaults)

        let status = SleepPreventionTriggerStatus.evaluate(
            preferences: RunnerPreferences(defaults: defaults),
            systemMetrics: makeMetrics(cpuLoadPercent: 92),
            codexAppRunning: false,
            externalVolumeCount: 0
        )

        XCTAssertTrue(status.isMatched)
        XCTAssertEqual(status.summary, "활성 · CPU 사용량")
    }

    func testCPUThresholdTriggerUsesConfiguredThreshold() {
        RunnerPreferences.setSleepPreventionCPUThresholdTrigger(true, defaults: defaults)
        RunnerPreferences.setSleepPreventionCPUThresholdPercent(65, defaults: defaults)

        let status = SleepPreventionTriggerStatus.evaluate(
            preferences: RunnerPreferences(defaults: defaults),
            systemMetrics: makeMetrics(cpuLoadPercent: 66),
            codexAppRunning: false,
            externalVolumeCount: 0
        )

        XCTAssertTrue(status.isMatched)
        XCTAssertEqual(status.cpuThresholdPercent, 65)
    }

    func testNetworkActivityTriggerMatchesWhenTrafficIsHigh() {
        RunnerPreferences.setSleepPreventionNetworkActivityTrigger(true, defaults: defaults)

        let status = SleepPreventionTriggerStatus.evaluate(
            preferences: RunnerPreferences(defaults: defaults),
            systemMetrics: makeMetrics(networkReceivedRateBytesPerSecond: 120 * 1024),
            codexAppRunning: false,
            externalVolumeCount: 0
        )

        XCTAssertTrue(status.isMatched)
        XCTAssertEqual(status.summary, "활성 · 네트워크 전송")
    }

    func testNetworkActivityTriggerUsesDefaultThreshold() {
        RunnerPreferences.setSleepPreventionNetworkActivityTrigger(true, defaults: defaults)
        RunnerPreferences.setSleepPreventionNetworkThresholdKBPerSecond(256, defaults: defaults)

        let status = SleepPreventionTriggerStatus.evaluate(
            preferences: RunnerPreferences(defaults: defaults),
            systemMetrics: makeMetrics(networkReceivedRateBytesPerSecond: 260 * 1024),
            codexAppRunning: false,
            externalVolumeCount: 0
        )

        XCTAssertTrue(status.isMatched)
        XCTAssertEqual(
            status.networkActivityThresholdBytesPerSecond,
            Double(RunnerPreferences.defaultSleepPreventionNetworkThresholdKBPerSecond) * 1024
        )
    }

    func testMemoryThresholdTriggerMatchesWhenUsageIsHigh() {
        RunnerPreferences.setSleepPreventionMemoryThresholdTrigger(true, defaults: defaults)
        RunnerPreferences.setSleepPreventionMemoryThresholdPercent(70, defaults: defaults)

        let status = SleepPreventionTriggerStatus.evaluate(
            preferences: RunnerPreferences(defaults: defaults),
            systemMetrics: makeMetrics(memoryUsedPercent: 71),
            codexAppRunning: false,
            externalVolumeCount: 0
        )

        XCTAssertTrue(status.isMatched)
        XCTAssertEqual(status.summary, "활성 · 메모리 사용량")
        XCTAssertEqual(status.memoryThresholdPercent, 70)
    }

    func testConfiguredAppTriggerUsesCodexLabelInSummary() {
        RunnerPreferences.setSleepPreventionCodexAppTrigger(true, defaults: defaults)
        RunnerPreferences.setSleepPreventionAppMatchText("Xcode", defaults: defaults)

        let status = SleepPreventionTriggerStatus.evaluate(
            preferences: RunnerPreferences(defaults: defaults),
            systemMetrics: makeMetrics(),
            codexAppRunning: true,
            externalVolumeCount: 0
        )

        XCTAssertTrue(status.isMatched)
        XCTAssertEqual(status.summary, "활성 · Codex 실행")
    }

    func testCaptureDoesNotReadRunningAppsWhenConfiguredAppTriggerIsDisabled() {
        RunnerPreferences.setSleepPreventionPowerAdapterTrigger(true, defaults: defaults)
        RunnerPreferences.setSleepPreventionCodexAppTrigger(false, defaults: defaults)

        let status = SleepPreventionTriggerStatus.capture(
            preferences: RunnerPreferences(defaults: defaults),
            systemMetrics: makeMetrics(battery: makeBattery(percent: 90, isConnectedToPower: true)),
            configuredAppRunningProvider: { _ in
                XCTFail("Configured app lookup should not run while its trigger is disabled")
                return true
            },
            externalVolumeCountProvider: {
                XCTFail("External volume lookup should not run while its trigger is disabled")
                return 1
            }
        )

        XCTAssertTrue(status.isMatched)
        XCTAssertFalse(status.codexAppRunning)
        XCTAssertEqual(status.externalVolumeCount, 0)
        XCTAssertEqual(status.summary, "활성 · 전원")
    }

    func testCaptureReadsRunningAppsOnlyWhenConfiguredAppTriggerIsEnabled() {
        RunnerPreferences.setSleepPreventionCodexAppTrigger(true, defaults: defaults)
        RunnerPreferences.setSleepPreventionAppMatchText("Xcode", defaults: defaults)

        var requestedMatchText: String?
        let status = SleepPreventionTriggerStatus.capture(
            preferences: RunnerPreferences(defaults: defaults),
            systemMetrics: makeMetrics(),
            configuredAppRunningProvider: { matchText in
                requestedMatchText = matchText
                return true
            },
            externalVolumeCountProvider: {
                XCTFail("External volume lookup should not run while its trigger is disabled")
                return 1
            }
        )

        XCTAssertEqual(requestedMatchText, "Xcode")
        XCTAssertTrue(status.isMatched)
        XCTAssertEqual(status.summary, "활성 · Codex 실행")
    }

    func testBatteryThresholdTriggerMatchesWhenBatteryHasEnoughCharge() {
        RunnerPreferences.setSleepPreventionChargingBelowThresholdTrigger(true, defaults: defaults)

        let status = SleepPreventionTriggerStatus.evaluate(
            preferences: RunnerPreferences(defaults: defaults),
            systemMetrics: makeMetrics(battery: makeBattery(percent: 30, isConnectedToPower: false)),
            codexAppRunning: false,
            externalVolumeCount: 0
        )

        XCTAssertTrue(status.isMatched)
        XCTAssertEqual(status.summary, "활성 · 배터리 30% 이상")
    }

    func testBatteryThresholdTriggerUsesConfiguredThreshold() {
        RunnerPreferences.setSleepPreventionChargingBelowThresholdTrigger(true, defaults: defaults)
        RunnerPreferences.setSleepPreventionBatteryThresholdPercent(70, defaults: defaults)

        let status = SleepPreventionTriggerStatus.evaluate(
            preferences: RunnerPreferences(defaults: defaults),
            systemMetrics: makeMetrics(battery: makeBattery(percent: 70, isConnectedToPower: true)),
            codexAppRunning: false,
            externalVolumeCount: 0
        )

        XCTAssertTrue(status.isMatched)
        XCTAssertEqual(status.summary, "활성 · 배터리 70% 이상")
    }

    func testBatteryThresholdTriggerWaitsWhenBatteryIsTooLow() {
        RunnerPreferences.setSleepPreventionChargingBelowThresholdTrigger(true, defaults: defaults)

        let status = SleepPreventionTriggerStatus.evaluate(
            preferences: RunnerPreferences(defaults: defaults),
            systemMetrics: makeMetrics(battery: makeBattery(percent: 29, isConnectedToPower: true)),
            codexAppRunning: false,
            externalVolumeCount: 0
        )

        XCTAssertFalse(status.isMatched)
        XCTAssertEqual(status.summary, "대기 중")
    }

    func testExternalVolumeTriggerMatchesMountedExternalVolume() {
        RunnerPreferences.setSleepPreventionExternalVolumeTrigger(true, defaults: defaults)

        let status = SleepPreventionTriggerStatus.evaluate(
            preferences: RunnerPreferences(defaults: defaults),
            systemMetrics: makeMetrics(),
            codexAppRunning: false,
            externalVolumeCount: 1
        )

        XCTAssertTrue(status.isMatched)
        XCTAssertEqual(status.summary, "활성 · 드라이브")
    }

    func testProviderOnlyTriggersCanUseUnavailableSystemMetrics() {
        RunnerPreferences.setSleepPreventionCodexAppTrigger(true, defaults: defaults)
        RunnerPreferences.setSleepPreventionExternalVolumeTrigger(true, defaults: defaults)

        let status = SleepPreventionTriggerStatus.capture(
            preferences: RunnerPreferences(defaults: defaults),
            systemMetrics: .unavailable,
            configuredAppRunningProvider: { _ in true },
            externalVolumeCountProvider: { 1 }
        )

        XCTAssertTrue(status.isMatched)
        XCTAssertTrue(status.codexAppRunning)
        XCTAssertTrue(status.externalVolumeConnected)
        XCTAssertNil(status.cpuLoadPercent)
        XCTAssertNil(status.memoryUsedPercent)
        XCTAssertNil(status.networkActivityBytesPerSecond)
    }

    private func makeMetrics(
        cpuLoadPercent: Double? = nil,
        memoryUsedPercent: Double? = nil,
        networkReceivedRateBytesPerSecond: Double? = nil,
        networkSentRateBytesPerSecond: Double? = nil,
        battery: BatteryStatusSnapshot = .unavailable
    ) -> SystemMetricsSnapshot {
        SystemMetricsSnapshot(
            capturedAt: Date(timeIntervalSince1970: 1_779_800_000),
            cpuLoadPercent: cpuLoadPercent,
            memoryUsedPercent: memoryUsedPercent,
            memoryDetails: nil,
            diskUsedPercent: nil,
            diskDetails: nil,
            networkReceivedBytes: nil,
            networkSentBytes: nil,
            networkReceivedRateBytesPerSecond: networkReceivedRateBytesPerSecond,
            networkSentRateBytesPerSecond: networkSentRateBytesPerSecond,
            activeInterfaceCount: 0,
            primaryNetworkInterfaceName: nil,
            localIPAddress: nil,
            cpuBreakdown: nil,
            battery: battery,
            chargeLimitSupport: .unavailable
        )
    }

    private func makeBattery(percent: Int, isConnectedToPower: Bool) -> BatteryStatusSnapshot {
        BatteryStatusSnapshot(
            isPresent: true,
            percent: percent,
            isCharging: isConnectedToPower,
            isCharged: false,
            isConnectedToPower: isConnectedToPower,
            timeToFullChargeMinutes: nil,
            timeToEmptyMinutes: nil,
            cycleCount: nil,
            temperatureCelsius: nil
        )
    }
}
