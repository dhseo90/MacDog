import MacDogPrivilegedHelperSupport
import SwiftUI

enum PopoverSummaryTone: Equatable {
    case neutral
    case good
    case warning

    var color: Color {
        switch self {
        case .neutral:
            return .secondary
        case .good:
            return .green
        case .warning:
            return .orange
        }
    }
}

struct PopoverTabSummaryContent: Equatable {
    let title: String
    let detail: String
    let nextAction: String
    let systemImage: String
    let tone: PopoverSummaryTone
}

struct PopoverStatusSummary: View {
    let content: PopoverTabSummaryContent

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: content.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(content.tone.color)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(content.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(content.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(content.nextAction)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(content.tone.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MacResourcesPanelSummaryContent: Equatable {
    let title: String
    let detail: String
    let nextAction: String
    let tone: PopoverSummaryTone

    init(snapshot: SystemMetricsSnapshot) {
        let hasPressure = (snapshot.cpuLoadPercent ?? 0) >= 80
            || (snapshot.memoryUsedPercent ?? 0) >= 80
            || (snapshot.diskUsedPercent ?? 0) >= 90
        let hasUnavailablePrimaryMetric = snapshot.cpuLoadPercent == nil
            || snapshot.memoryUsedPercent == nil
            || snapshot.diskUsedPercent == nil

        if hasPressure {
            title = "Mac 자원 주의"
            tone = .warning
        } else if hasUnavailablePrimaryMetric {
            title = "Mac 상태 확인 중"
            tone = .neutral
        } else {
            title = "Mac 상태 안정"
            tone = .good
        }

        detail = [
            "CPU \(snapshot.cpuSummary)",
            "메모리 \(snapshot.memorySummary)",
            "저장 용량 \(snapshot.diskSummary)"
        ].joined(separator: " · ")

        if hasPressure {
            nextAction = "다음 행동 · 높은 지표부터 자세히 확인하세요."
        } else if snapshot.networkReceivedRateBytesPerSecond != nil || snapshot.networkSentRateBytesPerSecond != nil {
            nextAction = "다음 행동 · 현재 속도와 누적 전송량을 분리해 확인하세요."
        } else {
            nextAction = "다음 행동 · 1초 갱신 후 네트워크 속도를 확인하세요."
        }
    }

    var popoverSummary: PopoverTabSummaryContent {
        PopoverTabSummaryContent(
            title: title,
            detail: detail,
            nextAction: nextAction,
            systemImage: "desktopcomputer",
            tone: tone
        )
    }
}

struct SleepPreventionPanelSummaryContent: Equatable {
    let title: String
    let detail: String
    let nextAction: String
    let tone: PopoverSummaryTone

    init(
        controlMode: SleepPreventionControlMode,
        status: SleepPreventionStatus,
        triggerStatus: SleepPreventionTriggerStatus
    ) {
        if let errorMessage = status.errorMessage {
            title = "잠자기 방지 오류"
            detail = errorMessage
            nextAction = "다음 행동 · 제어 방식을 끄고 오류 원인을 확인하세요."
            tone = .warning
            return
        }

        switch controlMode {
        case .off:
            title = "잠자기 방지 꺼짐"
            detail = "Mac이 평소 전원 정책을 따릅니다."
            nextAction = "다음 행동 · 필요하면 시간 제어 또는 상태 기준을 선택하세요."
            tone = .neutral
        case .time:
            title = status.isActive ? "시간 제어 켜짐" : "시간 제어 대기"
            detail = status.summary
            nextAction = "다음 행동 · 유지 시간이 끝나면 자동으로 꺼집니다."
            tone = status.isActive ? .good : .neutral
        case .condition:
            if triggerStatus.isMatched {
                title = "상태 기준 활성"
                detail = triggerStatus.summary
                nextAction = "다음 행동 · 필요 없는 기준을 끄면 바로 대기 상태로 돌아갑니다."
                tone = .good
            } else if triggerStatus.summary == "꺼짐" {
                title = "상태 기준 미설정"
                detail = "켜진 기준이 없습니다."
                nextAction = "다음 행동 · 전원, 앱, 자원 기준 중 필요한 조건만 켜세요."
                tone = .neutral
            } else {
                title = "상태 기준 대기"
                detail = triggerStatus.summary
                nextAction = "다음 행동 · 켜진 기준의 현재 충족 여부를 확인하세요."
                tone = .neutral
            }
        }
    }

    var popoverSummary: PopoverTabSummaryContent {
        PopoverTabSummaryContent(
            title: title,
            detail: detail,
            nextAction: nextAction,
            systemImage: "moon.zzz",
            tone: tone
        )
    }
}

struct BatteryPanelSummaryContent: Equatable {
    let title: String
    let detail: String
    let nextAction: String
    let tone: PopoverSummaryTone

    init(
        snapshot: SystemMetricsSnapshot,
        effectiveTargetPercent: Int,
        chargeLimitErrorMessage: String?
    ) {
        if let chargeLimitErrorMessage {
            title = "충전 한도 적용 실패"
            detail = chargeLimitErrorMessage
            nextAction = "다음 행동 · 배터리 설정에서 현재 한도를 확인하세요."
            tone = .warning
            return
        }

        let support = snapshot.chargeLimitSupport
        let currentLimitPercent = support.currentLimitPercent
        detail = Self.batteryDetail(snapshot.battery)

        if support.isNativeChargeLimitAvailable, let currentLimitPercent {
            title = "충전 한도 \(currentLimitPercent)% 적용됨"
            nextAction = "다음 행동 · 목표 한도는 80-100% 범위에서 조정하세요."
            tone = .good
        } else if support.isNativeChargeLimitAvailable {
            title = "충전 한도 제어 가능"
            nextAction = "다음 행동 · 목표 한도 \(effectiveTargetPercent)%를 적용할 수 있습니다."
            tone = .good
        } else if support.nativeState.errorMessage != nil {
            title = "충전 한도 확인 실패"
            nextAction = support.guidanceSummary
            tone = .warning
        } else {
            title = "충전 한도 미지원"
            nextAction = support.guidanceSummary
            tone = .neutral
        }
    }

    var popoverSummary: PopoverTabSummaryContent {
        PopoverTabSummaryContent(
            title: title,
            detail: detail,
            nextAction: nextAction,
            systemImage: "battery.100percent",
            tone: tone
        )
    }

    private static func batteryDetail(_ battery: BatteryStatusSnapshot) -> String {
        guard battery.isPresent else {
            return "배터리 정보를 확인하지 못했습니다."
        }

        let powerContext: String
        if battery.isConnectedToPower == true {
            powerContext = "전원 연결"
        } else if battery.isConnectedToPower == false {
            powerContext = "배터리 사용"
        } else {
            powerContext = "전원 상태 확인 불가"
        }
        return "\(battery.summary) · \(powerContext)"
    }
}

struct SettingsPanelSummaryContent: Equatable {
    let title: String
    let detail: String
    let nextAction: String
    let tone: PopoverSummaryTone

    init(
        notificationSettings: UsageNotificationSettingsSnapshot,
        privilegedHelperInstallSnapshot: PrivilegedHelperInstallSnapshot,
        loginLaunchEnabled: Bool,
        desktopPetEnabled: Bool,
        reducedMotion: Bool,
        animationPaused: Bool
    ) {
        title = notificationSettings.deliveryStatusTitle
        detail = [
            "로그인 실행 \(loginLaunchEnabled ? "켜짐" : "꺼짐")",
            privilegedHelperInstallSnapshot.summary,
            "펫 표시 \(desktopPetEnabled ? "켜짐" : "꺼짐")"
        ].joined(separator: " · ")

        if !notificationSettings.usageNotificationsEnabled {
            nextAction = "다음 행동 · 필요한 알림만 켜고 macOS 권한을 승인하세요."
            tone = .neutral
        } else if !notificationSettings.authorizationStatus.allowsDelivery {
            nextAction = "다음 행동 · macOS 알림 설정에서 MacDog 알림을 허용하세요."
            tone = .warning
        } else if privilegedHelperInstallSnapshot.requiresUserAction {
            nextAction = "다음 행동 · 덮개 닫힘 보호가 필요할 때만 도우미를 설치하세요."
            tone = .good
        } else if reducedMotion || animationPaused {
            nextAction = "다음 행동 · 움직임 옵션은 언제든 다시 조정할 수 있습니다."
            tone = .good
        } else {
            nextAction = "다음 행동 · 설정은 필요한 기능만 켜진 상태입니다."
            tone = .good
        }
    }

    var popoverSummary: PopoverTabSummaryContent {
        PopoverTabSummaryContent(
            title: title,
            detail: detail,
            nextAction: nextAction,
            systemImage: "gearshape",
            tone: tone
        )
    }
}
