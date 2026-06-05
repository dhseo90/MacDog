import XCTest
@testable import MacDog

final class UsageNotificationSettingsTests: XCTestCase {
    func testNotificationPreferencesDefaultToOptInOffAndResetSoonOn() throws {
        let suiteName = "UsageNotificationSettingsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        RunnerPreferences.registerDefaults(defaults: defaults)

        XCTAssertFalse(RunnerPreferences.usageNotificationsEnabled(defaults: defaults))
        XCTAssertTrue(RunnerPreferences.usageResetSoonNotificationsEnabled(defaults: defaults))

        let preferences = RunnerPreferences(defaults: defaults)
        XCTAssertFalse(preferences.usageNotificationsEnabled)
        XCTAssertTrue(preferences.usageResetSoonNotificationsEnabled)
    }

    func testNotificationSettingsSnapshotExplainsPermissionStatesWithoutTestButton() {
        let disabled = UsageNotificationSettingsSnapshot(
            usageNotificationsEnabled: false,
            resetSoonNotificationsEnabled: true,
            authorizationStatus: .notDetermined
        )

        XCTAssertEqual(disabled.deliveryStatusTitle, "알림 꺼짐")
        XCTAssertEqual(disabled.permissionSummary, "macOS 권한 미요청")
        XCTAssertEqual(disabled.deliveryStatusDetail, "알림을 켜기 전에는 macOS 권한을 요청하지 않습니다.")
        XCTAssertFalse(disabled.canDeliverNotifications)

        let denied = UsageNotificationSettingsSnapshot(
            usageNotificationsEnabled: true,
            resetSoonNotificationsEnabled: true,
            authorizationStatus: .denied
        )

        XCTAssertEqual(denied.deliveryStatusTitle, "권한 필요")
        XCTAssertEqual(denied.permissionSummary, "macOS 알림 꺼짐")
        XCTAssertEqual(denied.deliveryStatusDetail, "macOS 알림 설정에서 MacDog 알림을 허용해야 발송됩니다.")
        XCTAssertFalse(denied.canDeliverNotifications)

        let ready = UsageNotificationSettingsSnapshot(
            usageNotificationsEnabled: true,
            resetSoonNotificationsEnabled: true,
            authorizationStatus: .authorized
        )

        XCTAssertEqual(ready.deliveryStatusTitle, "알림 준비됨")
        XCTAssertTrue(ready.canDeliverNotifications)
        XCTAssertEqual(ready.visibleControlTitles, ["Codex 사용량 알림", "Reset 30분 전 알림"])
        XCTAssertFalse(ready.visibleControlTitles.contains("테스트 알림"))
    }
}
