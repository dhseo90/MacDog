struct PetMenuModel: Equatable {
    let title: String
    let entries: [PetMenuEntry]

    init(preferences: RunnerPreferences, surface: PetSurface) {
        self.title = "코덱스 펫"
        self.entries = [
            .command(PetMenuCommand(title: "사용량 상세 보기", action: .showUsageDetails)),
            .command(PetMenuCommand(title: "지금 새로고침", action: .refreshNow)),
            .separator,
            .submenu(Self.speedSubmenu(preferences: preferences)),
            .command(PetMenuCommand(
                title: "움직임 줄이기",
                action: .setReducedMotion(!preferences.reducedMotion),
                isSelected: preferences.reducedMotion
            )),
            .command(PetMenuCommand(
                title: "애니메이션 일시 정지",
                action: .setAnimationPaused(!preferences.animationPaused),
                isSelected: preferences.animationPaused
            )),
            .submenu(Self.sleepModeSubmenu(preferences: preferences)),
            .submenu(Self.sleepDurationSubmenu(preferences: preferences)),
            .submenu(Self.sleepPolicySubmenu(preferences: preferences)),
            .submenu(Self.sleepTriggerSubmenu(preferences: preferences)),
            .command(PetMenuCommand(title: "배터리 설정 열기", action: .openBatterySettings)),
            .separator,
            .command(Self.surfaceSwitchCommand(preferences: preferences, surface: surface)),
            .separator,
            .command(PetMenuCommand(title: "코덱스 사용량 종료", action: .quit))
        ]
    }

    var commands: [PetMenuCommand] {
        entries.flatMap(\.commands)
    }

    private static func speedSubmenu(preferences: RunnerPreferences) -> PetMenuSubmenu {
        PetMenuSubmenu(
            title: "러너 속도",
            commands: UsageDisplayBasis.allCases.map { basis in
                PetMenuCommand(
                    title: basis.label,
                    action: .setDisplayBasis(basis),
                    isSelected: preferences.displayBasis == basis
                )
            }
        )
    }

    private static func sleepModeSubmenu(preferences: RunnerPreferences) -> PetMenuSubmenu {
        PetMenuSubmenu(
            title: "잠자기 방지 모드",
            commands: SleepPreventionMode.allCases.map { mode in
                PetMenuCommand(
                    title: mode.label,
                    action: .setSleepPreventionMode(mode),
                    isSelected: preferences.sleepPreventionMode == mode
                )
            }
        )
    }

    private static func sleepDurationSubmenu(preferences: RunnerPreferences) -> PetMenuSubmenu {
        PetMenuSubmenu(
            title: "시간 기준 길이",
            commands: SleepPreventionSessionPreset.allCases.compactMap { preset in
                guard preset.durationMinutes != nil else { return nil }
                return PetMenuCommand(
                    title: preset.label,
                    action: .setSleepPreventionSessionPreset(preset),
                    isSelected: preferences.sleepPreventionSessionPreset == preset
                )
            },
            isEnabled: preferences.sleepPreventionMode == .timed
        )
    }

    private static func sleepPolicySubmenu(preferences: RunnerPreferences) -> PetMenuSubmenu {
        PetMenuSubmenu(
            title: "잠자기 방지 옵션",
            commands: [
                PetMenuCommand(
                    title: "화면 잠자기 방지",
                    action: .setSleepPreventionPreventDisplaySleep(!preferences.sleepPreventionPreventDisplaySleep),
                    isSelected: preferences.sleepPreventionPreventDisplaySleep
                ),
                PetMenuCommand(
                    title: "덮개 닫힘 보호",
                    action: .setSleepPreventionPreventClosedLidSleep(!preferences.sleepPreventionPreventClosedLidSleep),
                    isSelected: preferences.sleepPreventionPreventClosedLidSleep
                ),
                PetMenuCommand(
                    title: "잠금 요구 해제",
                    action: .setSleepPreventionDisableScreenLock(!preferences.sleepPreventionDisableScreenLock),
                    isSelected: preferences.sleepPreventionDisableScreenLock
                )
            ]
        )
    }

    private static func sleepTriggerSubmenu(preferences: RunnerPreferences) -> PetMenuSubmenu {
        PetMenuSubmenu(
            title: "자동 잠자기 방지",
            commands: [
                PetMenuCommand(
                    title: "전원 연결 중",
                    action: .setSleepPreventionPowerAdapterTrigger(!preferences.sleepPreventionPowerAdapterTriggerEnabled),
                    isSelected: preferences.sleepPreventionPowerAdapterTriggerEnabled
                ),
                PetMenuCommand(
                    title: "\(preferences.sleepPreventionAppMatchText) 앱 실행 중",
                    action: .setSleepPreventionCodexAppTrigger(!preferences.sleepPreventionCodexAppTriggerEnabled),
                    isSelected: preferences.sleepPreventionCodexAppTriggerEnabled
                ),
                PetMenuCommand(
                    title: "충전 \(preferences.sleepPreventionBatteryThresholdPercent)% 미만",
                    action: .setSleepPreventionChargingBelowThresholdTrigger(!preferences.sleepPreventionChargingBelowThresholdTriggerEnabled),
                    isSelected: preferences.sleepPreventionChargingBelowThresholdTriggerEnabled
                ),
                PetMenuCommand(
                    title: "CPU 사용 \(preferences.sleepPreventionCPUThresholdPercent)% 이상",
                    action: .setSleepPreventionCPUThresholdTrigger(!preferences.sleepPreventionCPUThresholdTriggerEnabled),
                    isSelected: preferences.sleepPreventionCPUThresholdTriggerEnabled
                ),
                PetMenuCommand(
                    title: "네트워크 \(preferences.sleepPreventionNetworkThresholdKBPerSecond)KB/s 이상",
                    action: .setSleepPreventionNetworkActivityTrigger(!preferences.sleepPreventionNetworkActivityTriggerEnabled),
                    isSelected: preferences.sleepPreventionNetworkActivityTriggerEnabled
                ),
                PetMenuCommand(
                    title: "외장/네트워크 볼륨 연결",
                    action: .setSleepPreventionExternalVolumeTrigger(!preferences.sleepPreventionExternalVolumeTriggerEnabled),
                    isSelected: preferences.sleepPreventionExternalVolumeTriggerEnabled
                )
            ]
        )
    }

    private static func surfaceSwitchCommand(preferences: RunnerPreferences, surface: PetSurface) -> PetMenuCommand {
        if preferences.desktopPetEnabled || surface == .desktop {
            return PetMenuCommand(title: "메뉴바로 돌아가기", action: .returnToMenuBar)
        }
        return PetMenuCommand(title: "데스크톱 펫 보기", action: .showDesktopPet)
    }
}

enum PetMenuEntry: Equatable {
    case command(PetMenuCommand)
    case submenu(PetMenuSubmenu)
    case separator

    var commands: [PetMenuCommand] {
        switch self {
        case .command(let command):
            [command]
        case .submenu(let submenu):
            submenu.commands
        case .separator:
            []
        }
    }
}

struct PetMenuSubmenu: Equatable {
    let title: String
    let commands: [PetMenuCommand]
    var isEnabled = true
}

struct PetMenuCommand: Equatable {
    let title: String
    let action: PetAction
    var isSelected = false
    var isEnabled = true
}
