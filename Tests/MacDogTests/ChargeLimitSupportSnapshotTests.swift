import XCTest
@testable import MacDog

final class ChargeLimitSupportSnapshotTests: XCTestCase {
    func testAppleSiliconOnSupportedOSShowsNativeChargeLimitAvailable() {
        let snapshot = ChargeLimitSupportSnapshot(
            operatingSystemVersion: OperatingSystemVersion(majorVersion: 26, minorVersion: 4, patchVersion: 0),
            isAppleSilicon: true,
            nativeState: NativeChargeLimitState(
                isSupported: true,
                availableLimits: [80, 85, 90, 95, 100],
                currentLimitPercent: 95,
                errorMessage: nil
            )
        )

        XCTAssertTrue(snapshot.isNativeChargeLimitAvailable)
        XCTAssertEqual(snapshot.summary, "시스템 한도 · 95%")
        XCTAssertEqual(snapshot.guidanceSummary, "목표보다 높으면 강제 방전하지 않고 충전을 멈춘 뒤 자연 하강합니다.")
    }

    func testIntelMacShowsAppleSiliconRequirement() {
        let snapshot = ChargeLimitSupportSnapshot(
            operatingSystemVersion: OperatingSystemVersion(majorVersion: 26, minorVersion: 4, patchVersion: 0),
            isAppleSilicon: false
        )

        XCTAssertFalse(snapshot.isNativeChargeLimitAvailable)
        XCTAssertEqual(snapshot.summary, "미지원 · Apple silicon 필요")
        XCTAssertEqual(snapshot.guidanceSummary, "이 Mac은 앱 제어를 지원하지 않아 배터리 설정에서 확인해야 합니다.")
    }

    func testAppleSiliconOnUnsupportedOSShowsVersionRequirement() {
        let snapshot = ChargeLimitSupportSnapshot(
            operatingSystemVersion: OperatingSystemVersion(majorVersion: 26, minorVersion: 3, patchVersion: 9),
            isAppleSilicon: true
        )

        XCTAssertFalse(snapshot.isNativeChargeLimitAvailable)
        XCTAssertEqual(snapshot.summary, "미지원 · macOS 26.4+ 필요")
        XCTAssertEqual(snapshot.guidanceSummary, "macOS 26.4 이상에서 앱 제어가 가능하며, 현재는 배터리 설정에서 확인하세요.")
    }

    func testNativeChargeLimitFailureShowsBatterySettingsFallbackGuidance() {
        let snapshot = ChargeLimitSupportSnapshot(
            operatingSystemVersion: OperatingSystemVersion(majorVersion: 26, minorVersion: 4, patchVersion: 0),
            isAppleSilicon: true,
            nativeState: NativeChargeLimitState(
                isSupported: false,
                availableLimits: [],
                currentLimitPercent: nil,
                errorMessage: "PowerUI 확인 실패"
            )
        )

        XCTAssertFalse(snapshot.isNativeChargeLimitAvailable)
        XCTAssertEqual(snapshot.summary, "확인 실패 · PowerUI 확인 실패")
        XCTAssertEqual(snapshot.guidanceSummary, "앱에서 충전 한도를 확인하지 못했습니다. 배터리 설정에서 직접 확인하세요.")
    }

    func testBatterySettingsDestinationStartsWithSystemSettingsURL() throws {
        let firstURL = try XCTUnwrap(SystemSettingsDestination.batterySettingsURLCandidates.first)

        XCTAssertEqual(firstURL.scheme, "x-apple.systempreferences")
        XCTAssertEqual(firstURL.absoluteString, "x-apple.systempreferences:com.apple.Battery-Settings.extension")
    }

    func testLockScreenSettingsDestinationStartsWithSystemSettingsURL() throws {
        let firstURL = try XCTUnwrap(SystemSettingsDestination.lockScreenSettingsURLCandidates.first)

        XCTAssertEqual(firstURL.scheme, "x-apple.systempreferences")
        XCTAssertEqual(firstURL.absoluteString, "x-apple.systempreferences:com.apple.Lock-Screen-Settings.extension")
    }

    func testChargeLimitTargetPreferenceClampsAndRoundsToNativeRange() throws {
        let suiteName = "MacDogChargeLimitTargetPreferenceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        XCTAssertEqual(RunnerPreferences.chargeLimitTargetPercent(defaults: defaults), 80)

        RunnerPreferences.setChargeLimitTargetPercent(83, defaults: defaults)
        XCTAssertEqual(RunnerPreferences.chargeLimitTargetPercent(defaults: defaults), 85)

        RunnerPreferences.setChargeLimitTargetPercent(101, defaults: defaults)
        XCTAssertEqual(RunnerPreferences.chargeLimitTargetPercent(defaults: defaults), 100)

        RunnerPreferences.setChargeLimitTargetPercent(77, defaults: defaults)
        XCTAssertEqual(RunnerPreferences.chargeLimitTargetPercent(defaults: defaults), 80)
    }

    func testBatterySummaryDistinguishesConnectedButNotCharging() {
        let snapshot = BatteryStatusSnapshot(
            isPresent: true,
            percent: 95,
            isCharging: false,
            isCharged: false,
            isConnectedToPower: true,
            timeToFullChargeMinutes: nil,
            timeToEmptyMinutes: nil,
            cycleCount: 7,
            temperatureCelsius: 30.1
        )

        XCTAssertEqual(snapshot.summary, "95% · 충전 안 함")
        XCTAssertEqual(snapshot.powerSummary, "전원 연결 · 충전 안 함")
        XCTAssertEqual(snapshot.detailSummary, "사이클 7회 · 온도 30.1°C")
        XCTAssertEqual(snapshot.cycleSummary, "7회")
        XCTAssertEqual(snapshot.temperatureSummary, "30.1°C")
    }

    func testBatteryInfoSummariesHandleMissingDetails() {
        let snapshot = BatteryStatusSnapshot(
            isPresent: true,
            percent: 95,
            isCharging: false,
            isCharged: false,
            isConnectedToPower: true,
            timeToFullChargeMinutes: nil,
            timeToEmptyMinutes: nil,
            cycleCount: nil,
            temperatureCelsius: nil
        )

        XCTAssertEqual(snapshot.detailSummary, "세부 정보 없음")
        XCTAssertEqual(snapshot.cycleSummary, "확인 불가")
        XCTAssertEqual(snapshot.temperatureSummary, "확인 불가")
    }

    func testFloatingPetMenuPlacementUsesRightSideInLeftHalfOfScreen() {
        let placement = FloatingPetMenuPlacement.resolve(
            petFrame: NSRect(x: 120, y: 200, width: 96, height: 102),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800),
            clickPoint: NSPoint(x: 160, y: 240),
            menuSize: NSSize(width: 220, height: 260)
        )

        XCTAssertEqual(placement.side, .right)
        XCTAssertEqual(placement.origin.x, 224)
    }

    func testFloatingPetMenuPlacementUsesLeftSideInRightHalfOfScreen() {
        let placement = FloatingPetMenuPlacement.resolve(
            petFrame: NSRect(x: 820, y: 200, width: 96, height: 102),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800),
            clickPoint: NSPoint(x: 850, y: 240),
            menuSize: NSSize(width: 220, height: 260)
        )

        XCTAssertEqual(placement.side, .left)
        XCTAssertEqual(placement.origin.x, 592)
    }

    func testFloatingPetMenuPlacementClampsInsideVisibleFrame() {
        let placement = FloatingPetMenuPlacement.resolve(
            petFrame: NSRect(x: 940, y: 10, width: 96, height: 102),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800),
            clickPoint: NSPoint(x: 960, y: 20),
            menuSize: NSSize(width: 900, height: 760)
        )

        XCTAssertEqual(placement.side, .left)
        XCTAssertGreaterThanOrEqual(placement.origin.x, 8)
        XCTAssertLessThanOrEqual(placement.origin.x + 900, 992)
        XCTAssertGreaterThanOrEqual(placement.origin.y, 768)
        XCTAssertLessThanOrEqual(placement.origin.y, 792)
    }
}
