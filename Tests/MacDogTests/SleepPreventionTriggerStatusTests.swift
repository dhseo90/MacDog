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

    func testCPUThresholdTriggerMatchesWhenLoadIsHigh() {
        RunnerPreferences.setSleepPreventionCPUThresholdTrigger(true, defaults: defaults)

        let status = SleepPreventionTriggerStatus.evaluate(
            preferences: RunnerPreferences(defaults: defaults),
            systemMetrics: makeMetrics(cpuLoadPercent: 92),
            codexAppRunning: false,
            externalVolumeCount: 0
        )

        XCTAssertTrue(status.isMatched)
        XCTAssertEqual(status.summary, "활성 · CPU")
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
        XCTAssertEqual(status.summary, "활성 · 네트워크")
    }

    func testChargingBelowThresholdTriggerRequiresPowerAndLowBattery() {
        RunnerPreferences.setSleepPreventionChargingBelowThresholdTrigger(true, defaults: defaults)

        let status = SleepPreventionTriggerStatus.evaluate(
            preferences: RunnerPreferences(defaults: defaults),
            systemMetrics: makeMetrics(battery: makeBattery(percent: 72, isConnectedToPower: true)),
            codexAppRunning: false,
            externalVolumeCount: 0
        )

        XCTAssertTrue(status.isMatched)
        XCTAssertEqual(status.summary, "활성 · 충전 80% 미만")
    }

    func testChargingBelowThresholdTriggerWaitsWithoutPower() {
        RunnerPreferences.setSleepPreventionChargingBelowThresholdTrigger(true, defaults: defaults)

        let status = SleepPreventionTriggerStatus.evaluate(
            preferences: RunnerPreferences(defaults: defaults),
            systemMetrics: makeMetrics(battery: makeBattery(percent: 72, isConnectedToPower: false)),
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
        XCTAssertEqual(status.summary, "활성 · 볼륨")
    }

    private func makeMetrics(
        cpuLoadPercent: Double? = nil,
        networkReceivedRateBytesPerSecond: Double? = nil,
        networkSentRateBytesPerSecond: Double? = nil,
        battery: BatteryStatusSnapshot = .unavailable
    ) -> SystemMetricsSnapshot {
        SystemMetricsSnapshot(
            capturedAt: Date(timeIntervalSince1970: 1_779_800_000),
            cpuLoadPercent: cpuLoadPercent,
            memoryUsedPercent: nil,
            memoryDetails: nil,
            diskUsedPercent: nil,
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
