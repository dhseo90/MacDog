import Foundation
import UserNotifications

enum UsageNotificationAuthorizationStatus: Equatable, Sendable {
    case unknown
    case notDetermined
    case denied
    case authorized

    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .denied:
            self = .denied
        case .authorized, .provisional:
            self = .authorized
        @unknown default:
            self = .unknown
        }
    }

    var permissionSummary: String {
        switch self {
        case .unknown:
            "macOS 권한 확인 중"
        case .notDetermined:
            "macOS 권한 미요청"
        case .denied:
            "macOS 알림 꺼짐"
        case .authorized:
            "macOS 알림 허용됨"
        }
    }

    var allowsDelivery: Bool {
        self == .authorized
    }
}

struct UsageNotificationSettingsSnapshot: Equatable, Sendable {
    let usageNotificationsEnabled: Bool
    let resetSoonNotificationsEnabled: Bool
    let authorizationStatus: UsageNotificationAuthorizationStatus

    var canDeliverNotifications: Bool {
        usageNotificationsEnabled && authorizationStatus.allowsDelivery
    }

    var deliveryStatusTitle: String {
        guard usageNotificationsEnabled else {
            return "알림 꺼짐"
        }

        switch authorizationStatus {
        case .authorized:
            return "알림 준비됨"
        case .denied:
            return "권한 필요"
        case .notDetermined:
            return "권한 승인 대기"
        case .unknown:
            return "권한 확인 중"
        }
    }

    var permissionSummary: String {
        authorizationStatus.permissionSummary
    }

    var deliveryStatusDetail: String {
        guard usageNotificationsEnabled else {
            return "알림을 켜기 전에는 macOS 권한을 요청하지 않습니다."
        }

        switch authorizationStatus {
        case .authorized:
            return resetSoonNotificationsEnabled
                ? "80%, 95%, 한도 도달, reset 30분 전 기준을 확인합니다."
                : "80%, 95%, 한도 도달 기준을 확인합니다."
        case .denied:
            return "macOS 알림 설정에서 MacDog 알림을 허용해야 발송됩니다."
        case .notDetermined:
            return "알림을 켜면 macOS 권한 승인을 요청합니다."
        case .unknown:
            return "권한 상태를 확인한 뒤 발송 가능 여부를 표시합니다."
        }
    }

    var visibleControlTitles: [String] {
        ["Codex 사용량 알림", "Reset 30분 전 알림"]
    }
}

protocol UsageNotificationAuthorizationProviding: Sendable {
    func authorizationStatus() async -> UsageNotificationAuthorizationStatus
    func requestAuthorization() async -> UsageNotificationAuthorizationStatus
}

struct UsageNotificationAuthorizationClient: UsageNotificationAuthorizationProviding {
    func authorizationStatus() async -> UsageNotificationAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return UsageNotificationAuthorizationStatus(settings.authorizationStatus)
    }

    func requestAuthorization() async -> UsageNotificationAuthorizationStatus {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            return await authorizationStatus()
        }

        return await authorizationStatus()
    }
}

struct StaticUsageNotificationAuthorizationClient: UsageNotificationAuthorizationProviding {
    let status: UsageNotificationAuthorizationStatus

    func authorizationStatus() async -> UsageNotificationAuthorizationStatus {
        status
    }

    func requestAuthorization() async -> UsageNotificationAuthorizationStatus {
        status
    }
}
