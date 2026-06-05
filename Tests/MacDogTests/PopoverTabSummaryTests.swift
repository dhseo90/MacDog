import MacDogPrivilegedHelperSupport
import XCTest
@testable import MacDog

final class PopoverTabSummaryTests: XCTestCase {
    func testMacResourcesSummaryLeadsWithCurrentResourceState() {
        let summary = MacResourcesPanelSummaryContent(
            snapshot: makeMetrics(
                cpuLoadPercent: 24.9,
                memoryUsedPercent: 49.1,
                diskUsedPercent: 77.4,
                networkReceivedRateBytesPerSecond: 31_100,
                networkSentRateBytesPerSecond: 352_100
            )
        )

        XCTAssertEqual(summary.title, "Mac 상태 안정")
        XCTAssertEqual(summary.detail, "CPU 24.9% 사용 중 · 메모리 49.1% 사용 · 저장 용량 77.4% 사용")
        XCTAssertEqual(summary.nextAction, "다음 행동 · 현재 속도와 누적 전송량을 분리해 확인하세요.")
        XCTAssertEqual(summary.tone, .good)
    }

    func testSleepSummaryShowsMatchedConditionTriggersAndNextAction() {
        let summary = SleepPreventionPanelSummaryContent(
            controlMode: .condition,
            status: SleepPreventionStatus(
                isEnabled: true,
                isActive: true,
                endsAt: nil,
                isClosedLidSleepDisabled: true,
                isScreenLockDisabled: true,
                errorMessage: nil,
                closedLidWarningMessage: nil,
                screenLockWarningMessage: nil
            ),
            triggerStatus: SleepPreventionTriggerStatus(
                powerAdapterTriggerEnabled: true,
                codexAppTriggerEnabled: true,
                chargingBelowThresholdTriggerEnabled: false,
                cpuThresholdTriggerEnabled: false,
                memoryThresholdTriggerEnabled: false,
                networkActivityTriggerEnabled: true,
                externalVolumeTriggerEnabled: false,
                powerAdapterConnected: true,
                codexAppRunning: true,
                appMatchText: "Codex",
                chargingBelowThreshold: false,
                cpuAboveThreshold: false,
                memoryAboveThreshold: false,
                networkActivityAboveThreshold: true,
                externalVolumeConnected: false,
                batteryPercent: 94,
                batteryThresholdPercent: 30,
                cpuLoadPercent: 24.9,
                cpuThresholdPercent: 20,
                memoryUsedPercent: 49.1,
                memoryThresholdPercent: 20,
                networkActivityBytesPerSecond: 383_200,
                networkActivityThresholdBytesPerSecond: 256 * 1024,
                externalVolumeCount: 0
            )
        )

        XCTAssertEqual(summary.title, "상태 기준 활성")
        XCTAssertEqual(summary.detail, "활성 · 전원, Codex 실행, 네트워크 전송")
        XCTAssertEqual(summary.nextAction, "다음 행동 · 필요 없는 기준을 끄면 바로 대기 상태로 돌아갑니다.")
        XCTAssertEqual(summary.tone, .good)
    }

    func testBatterySummaryDistinguishesAppliedLimitFromTarget() {
        let metrics = makeMetrics(
            battery: BatteryStatusSnapshot(
                isPresent: true,
                percent: 94,
                isCharging: false,
                isCharged: false,
                isConnectedToPower: true,
                timeToFullChargeMinutes: nil,
                timeToEmptyMinutes: nil,
                cycleCount: 7,
                temperatureCelsius: 30.1
            ),
            chargeLimitSupport: ChargeLimitSupportSnapshot(
                operatingSystemVersion: OperatingSystemVersion(majorVersion: 26, minorVersion: 4, patchVersion: 0),
                isAppleSilicon: true,
                nativeState: NativeChargeLimitState(
                    isSupported: true,
                    availableLimits: [80, 85, 90, 95, 100],
                    currentLimitPercent: 90,
                    errorMessage: nil
                )
            )
        )

        let summary = BatteryPanelSummaryContent(
            snapshot: metrics,
            effectiveTargetPercent: 90,
            chargeLimitErrorMessage: nil
        )

        XCTAssertEqual(summary.title, "충전 한도 90% 적용됨")
        XCTAssertEqual(summary.detail, "94% · 충전 안 함 · 전원 연결")
        XCTAssertEqual(summary.nextAction, "다음 행동 · 목표 한도는 80-100% 범위에서 조정하세요.")
        XCTAssertEqual(summary.tone, .good)
    }

    func testBatterySummaryShowsApplyFailureAsSeparateState() {
        let summary = BatteryPanelSummaryContent(
            snapshot: makeMetrics(chargeLimitSupport: .unavailable),
            effectiveTargetPercent: 90,
            chargeLimitErrorMessage: "적용 실패 · PowerUI 쓰기 실패"
        )

        XCTAssertEqual(summary.title, "충전 한도 적용 실패")
        XCTAssertEqual(summary.detail, "적용 실패 · PowerUI 쓰기 실패")
        XCTAssertEqual(summary.nextAction, "다음 행동 · 배터리 설정에서 현재 한도를 확인하세요.")
        XCTAssertEqual(summary.tone, .warning)
    }

    func testSettingsSummaryPrioritizesNotificationAndHelperState() {
        let summary = SettingsPanelSummaryContent(
            notificationSettings: UsageNotificationSettingsSnapshot(
                usageNotificationsEnabled: false,
                resetSoonNotificationsEnabled: true,
                authorizationStatus: .notDetermined
            ),
            privilegedHelperInstallSnapshot: PrivilegedHelperInstallSnapshot(
                helperToolExists: false,
                launchDaemonExists: false
            ),
            loginLaunchEnabled: true,
            desktopPetEnabled: true,
            reducedMotion: false,
            animationPaused: false
        )

        XCTAssertEqual(summary.title, "알림 꺼짐")
        XCTAssertEqual(summary.detail, "로그인 실행 켜짐 · 권한 도우미 미설치 · 펫 표시 켜짐")
        XCTAssertEqual(summary.nextAction, "다음 행동 · 필요한 알림만 켜고 macOS 권한을 승인하세요.")
        XCTAssertEqual(summary.tone, .neutral)
    }

    private func makeMetrics(
        cpuLoadPercent: Double? = nil,
        memoryUsedPercent: Double? = nil,
        diskUsedPercent: Double? = nil,
        networkReceivedRateBytesPerSecond: Double? = nil,
        networkSentRateBytesPerSecond: Double? = nil,
        battery: BatteryStatusSnapshot = .unavailable,
        chargeLimitSupport: ChargeLimitSupportSnapshot = .unavailable
    ) -> SystemMetricsSnapshot {
        SystemMetricsSnapshot(
            capturedAt: Date(timeIntervalSince1970: 1_780_401_600),
            cpuLoadPercent: cpuLoadPercent,
            memoryUsedPercent: memoryUsedPercent,
            memoryDetails: nil,
            diskUsedPercent: diskUsedPercent,
            diskDetails: nil,
            networkReceivedBytes: 2_400_000_000,
            networkSentBytes: 2_000_000_000,
            networkReceivedRateBytesPerSecond: networkReceivedRateBytesPerSecond,
            networkSentRateBytesPerSecond: networkSentRateBytesPerSecond,
            activeInterfaceCount: 1,
            primaryNetworkInterfaceName: "Wi-Fi",
            localIPAddress: "192.168.219.112",
            cpuBreakdown: nil,
            battery: battery,
            chargeLimitSupport: chargeLimitSupport
        )
    }
}
