import Foundation
import AppKit

struct RunnerPreferences: Equatable {
    static let displayBasisKey = "displayBasis"
    static let popoverModuleKey = "macDogPopoverModule"
    static let reducedMotionKey = "reducedMotion"
    static let animationPausedKey = "animationPaused"
    static let desktopPetEnabledKey = "desktopPetEnabled"
    static let sleepPreventionControlModeKey = "sleepPreventionControlMode"
    static let sleepPreventionEnabledKey = "sleepPreventionEnabled"
    static let sleepPreventionSessionPresetKey = "sleepPreventionSessionPreset"
    static let sleepPreventionEndsAtKey = "sleepPreventionEndsAt"
    static let sleepPreventionPowerAdapterTriggerKey = "sleepPreventionPowerAdapterTrigger"
    static let sleepPreventionCodexAppTriggerKey = "sleepPreventionCodexAppTrigger"
    static let sleepPreventionChargingBelowThresholdTriggerKey = "sleepPreventionChargingBelowThresholdTrigger"
    static let sleepPreventionCPUThresholdTriggerKey = "sleepPreventionCPUThresholdTrigger"
    static let sleepPreventionNetworkActivityTriggerKey = "sleepPreventionNetworkActivityTrigger"
    static let sleepPreventionExternalVolumeTriggerKey = "sleepPreventionExternalVolumeTrigger"
    static let sleepPreventionBatteryThresholdPercentKey = "sleepPreventionBatteryThresholdPercent"
    static let sleepPreventionCPUThresholdPercentKey = "sleepPreventionCPUThresholdPercent"
    static let sleepPreventionNetworkThresholdKBPerSecondKey = "sleepPreventionNetworkThresholdKBPerSecond"
    static let sleepPreventionAppMatchTextKey = "sleepPreventionAppMatchText"
    static let sleepPreventionPreventDisplaySleepKey = "sleepPreventionPreventDisplaySleep"
    static let sleepPreventionPreventClosedLidSleepKey = "sleepPreventionPreventClosedLidSleep"
    static let sleepPreventionDisableScreenLockKey = "sleepPreventionDisableScreenLock"
    static let chargeLimitTargetPercentKey = "chargeLimitTargetPercent"
    static let desktopPetOriginXKey = "desktopPetOriginX"
    static let desktopPetOriginYKey = "desktopPetOriginY"
    static let defaultDisplayBasis = UsageDisplayBasis.weekly
    static let defaultSleepPreventionControlMode = SleepPreventionControlMode.off
    static let defaultSleepPreventionSessionPreset = SleepPreventionSessionPreset.indefinite
    static let defaultChargeLimitTargetPercent = 80
    static let minimumChargeLimitTargetPercent = 80
    static let maximumChargeLimitTargetPercent = 100
    static let chargeLimitTargetStepPercent = 5
    static let defaultSleepPreventionBatteryThresholdPercent = 80
    static let defaultSleepPreventionCPUThresholdPercent = 80
    static let defaultSleepPreventionNetworkThresholdKBPerSecond = 100
    static let defaultSleepPreventionAppMatchText = "codex"
    static let defaultSleepPreventionPreventDisplaySleep = true
    static let defaultSleepPreventionPreventClosedLidSleep = true
    static let defaultSleepPreventionDisableScreenLock = true
    static let minimumSleepPreventionBatteryThresholdPercent = 20
    static let maximumSleepPreventionBatteryThresholdPercent = 95
    static let minimumSleepPreventionCPUThresholdPercent = 10
    static let maximumSleepPreventionCPUThresholdPercent = 100
    static let minimumSleepPreventionNetworkThresholdKBPerSecond = 10
    static let maximumSleepPreventionNetworkThresholdKBPerSecond = 1_024

    static func registerDefaults(defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            displayBasisKey: defaultDisplayBasis.rawValue,
            reducedMotionKey: false,
            animationPausedKey: false,
            desktopPetEnabledKey: false,
            sleepPreventionControlModeKey: defaultSleepPreventionControlMode.rawValue,
            sleepPreventionEnabledKey: false,
            sleepPreventionSessionPresetKey: defaultSleepPreventionSessionPreset.rawValue,
            sleepPreventionPowerAdapterTriggerKey: false,
            sleepPreventionCodexAppTriggerKey: false,
            sleepPreventionChargingBelowThresholdTriggerKey: false,
            sleepPreventionCPUThresholdTriggerKey: false,
            sleepPreventionNetworkActivityTriggerKey: false,
            sleepPreventionExternalVolumeTriggerKey: false,
            sleepPreventionBatteryThresholdPercentKey: defaultSleepPreventionBatteryThresholdPercent,
            sleepPreventionCPUThresholdPercentKey: defaultSleepPreventionCPUThresholdPercent,
            sleepPreventionNetworkThresholdKBPerSecondKey: defaultSleepPreventionNetworkThresholdKBPerSecond,
            sleepPreventionAppMatchTextKey: defaultSleepPreventionAppMatchText,
            sleepPreventionPreventDisplaySleepKey: defaultSleepPreventionPreventDisplaySleep,
            sleepPreventionPreventClosedLidSleepKey: defaultSleepPreventionPreventClosedLidSleep,
            sleepPreventionDisableScreenLockKey: defaultSleepPreventionDisableScreenLock,
            chargeLimitTargetPercentKey: defaultChargeLimitTargetPercent
        ])
    }

    let displayBasis: UsageDisplayBasis
    let reducedMotion: Bool
    let animationPaused: Bool
    let desktopPetEnabled: Bool
    let sleepPreventionControlMode: SleepPreventionControlMode
    let sleepPreventionEnabled: Bool
    let sleepPreventionSessionPreset: SleepPreventionSessionPreset
    let sleepPreventionEndsAt: Date?
    let sleepPreventionPowerAdapterTriggerEnabled: Bool
    let sleepPreventionCodexAppTriggerEnabled: Bool
    let sleepPreventionChargingBelowThresholdTriggerEnabled: Bool
    let sleepPreventionCPUThresholdTriggerEnabled: Bool
    let sleepPreventionNetworkActivityTriggerEnabled: Bool
    let sleepPreventionExternalVolumeTriggerEnabled: Bool
    let sleepPreventionBatteryThresholdPercent: Int
    let sleepPreventionCPUThresholdPercent: Int
    let sleepPreventionNetworkThresholdKBPerSecond: Int
    let sleepPreventionAppMatchText: String
    let sleepPreventionPreventDisplaySleep: Bool
    let sleepPreventionPreventClosedLidSleep: Bool
    let sleepPreventionDisableScreenLock: Bool
    let chargeLimitTargetPercent: Int

    var sleepPreventionMode: SleepPreventionMode {
        switch sleepPreventionControlMode {
        case .off:
            return .off
        case .time:
            return sleepPreventionSessionPreset.durationMinutes == nil ? .always : .timed
        case .condition:
            if sleepPreventionPowerAdapterTriggerEnabled {
                return .charging
            }
            if sleepPreventionCodexAppTriggerEnabled {
                return .application
            }
            return .condition
        }
    }

    var sleepPreventionPolicy: SleepPreventionPolicy {
        SleepPreventionPolicy(
            preventDisplaySleep: sleepPreventionPreventDisplaySleep,
            preventClosedLidSleep: sleepPreventionPreventClosedLidSleep,
            disableScreenLock: sleepPreventionDisableScreenLock
        )
    }

    init(defaults: UserDefaults = .standard) {
        self.displayBasis = UsageDisplayBasis(rawValue: defaults.string(forKey: Self.displayBasisKey) ?? "") ?? Self.defaultDisplayBasis
        self.reducedMotion = defaults.bool(forKey: Self.reducedMotionKey)
        self.animationPaused = defaults.bool(forKey: Self.animationPausedKey)
        self.desktopPetEnabled = defaults.bool(forKey: Self.desktopPetEnabledKey)
        self.sleepPreventionEnabled = defaults.bool(forKey: Self.sleepPreventionEnabledKey)
        self.sleepPreventionSessionPreset = SleepPreventionSessionPreset(rawValue: defaults.string(forKey: Self.sleepPreventionSessionPresetKey) ?? "") ?? Self.defaultSleepPreventionSessionPreset
        if defaults.object(forKey: Self.sleepPreventionEndsAtKey) != nil {
            self.sleepPreventionEndsAt = Date(timeIntervalSince1970: defaults.double(forKey: Self.sleepPreventionEndsAtKey))
        } else {
            self.sleepPreventionEndsAt = nil
        }
        self.sleepPreventionPowerAdapterTriggerEnabled = defaults.bool(forKey: Self.sleepPreventionPowerAdapterTriggerKey)
        self.sleepPreventionCodexAppTriggerEnabled = defaults.bool(forKey: Self.sleepPreventionCodexAppTriggerKey)
        self.sleepPreventionChargingBelowThresholdTriggerEnabled = defaults.bool(forKey: Self.sleepPreventionChargingBelowThresholdTriggerKey)
        self.sleepPreventionCPUThresholdTriggerEnabled = defaults.bool(forKey: Self.sleepPreventionCPUThresholdTriggerKey)
        self.sleepPreventionNetworkActivityTriggerEnabled = defaults.bool(forKey: Self.sleepPreventionNetworkActivityTriggerKey)
        self.sleepPreventionExternalVolumeTriggerEnabled = defaults.bool(forKey: Self.sleepPreventionExternalVolumeTriggerKey)
        self.sleepPreventionBatteryThresholdPercent = Self.sleepPreventionBatteryThresholdPercent(defaults: defaults)
        self.sleepPreventionCPUThresholdPercent = Self.sleepPreventionCPUThresholdPercent(defaults: defaults)
        self.sleepPreventionNetworkThresholdKBPerSecond = Self.sleepPreventionNetworkThresholdKBPerSecond(defaults: defaults)
        self.sleepPreventionAppMatchText = Self.sleepPreventionAppMatchText(defaults: defaults)
        self.sleepPreventionPreventDisplaySleep = Self.sleepPreventionPreventDisplaySleep(defaults: defaults)
        self.sleepPreventionPreventClosedLidSleep = Self.sleepPreventionPreventClosedLidSleep(defaults: defaults)
        self.sleepPreventionDisableScreenLock = Self.sleepPreventionDisableScreenLock(defaults: defaults)
        self.chargeLimitTargetPercent = Self.chargeLimitTargetPercent(defaults: defaults)

        let storedMode = SleepPreventionControlMode(rawValue: defaults.string(forKey: Self.sleepPreventionControlModeKey) ?? "")
            ?? Self.defaultSleepPreventionControlMode
        if sleepPreventionEnabled {
            self.sleepPreventionControlMode = .time
        } else if Self.hasAutomaticSleepPreventionTrigger(defaults: defaults) {
            self.sleepPreventionControlMode = .condition
        } else {
            self.sleepPreventionControlMode = storedMode == .condition ? .condition : .off
        }
    }

    static func setDisplayBasis(_ basis: UsageDisplayBasis, defaults: UserDefaults = .standard) {
        defaults.set(basis.rawValue, forKey: displayBasisKey)
    }

    static func setReducedMotion(_ isEnabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(isEnabled, forKey: reducedMotionKey)
    }

    static func setAnimationPaused(_ isPaused: Bool, defaults: UserDefaults = .standard) {
        defaults.set(isPaused, forKey: animationPausedKey)
    }

    static func chargeLimitTargetPercent(defaults: UserDefaults = .standard) -> Int {
        guard defaults.object(forKey: chargeLimitTargetPercentKey) != nil else {
            return defaultChargeLimitTargetPercent
        }
        return normalizedChargeLimitTargetPercent(defaults.integer(forKey: chargeLimitTargetPercentKey))
    }

    static func setChargeLimitTargetPercent(_ percent: Int, defaults: UserDefaults = .standard) {
        defaults.set(normalizedChargeLimitTargetPercent(percent), forKey: chargeLimitTargetPercentKey)
    }

    static func normalizedChargeLimitTargetPercent(_ percent: Int) -> Int {
        let clamped = min(max(percent, minimumChargeLimitTargetPercent), maximumChargeLimitTargetPercent)
        let offset = clamped - minimumChargeLimitTargetPercent
        let roundedSteps = Int((Double(offset) / Double(chargeLimitTargetStepPercent)).rounded())
        return minimumChargeLimitTargetPercent + roundedSteps * chargeLimitTargetStepPercent
    }

    static func sleepPreventionBatteryThresholdPercent(defaults: UserDefaults = .standard) -> Int {
        guard defaults.object(forKey: sleepPreventionBatteryThresholdPercentKey) != nil else {
            return defaultSleepPreventionBatteryThresholdPercent
        }
        return normalizedSleepPreventionBatteryThresholdPercent(defaults.integer(forKey: sleepPreventionBatteryThresholdPercentKey))
    }

    static func setSleepPreventionBatteryThresholdPercent(_ percent: Int, defaults: UserDefaults = .standard) {
        defaults.set(
            normalizedSleepPreventionBatteryThresholdPercent(percent),
            forKey: sleepPreventionBatteryThresholdPercentKey
        )
    }

    static func normalizedSleepPreventionBatteryThresholdPercent(_ percent: Int) -> Int {
        min(max(percent, minimumSleepPreventionBatteryThresholdPercent), maximumSleepPreventionBatteryThresholdPercent)
    }

    static func sleepPreventionCPUThresholdPercent(defaults: UserDefaults = .standard) -> Int {
        guard defaults.object(forKey: sleepPreventionCPUThresholdPercentKey) != nil else {
            return defaultSleepPreventionCPUThresholdPercent
        }
        return normalizedSleepPreventionCPUThresholdPercent(defaults.integer(forKey: sleepPreventionCPUThresholdPercentKey))
    }

    static func setSleepPreventionCPUThresholdPercent(_ percent: Int, defaults: UserDefaults = .standard) {
        defaults.set(
            normalizedSleepPreventionCPUThresholdPercent(percent),
            forKey: sleepPreventionCPUThresholdPercentKey
        )
    }

    static func normalizedSleepPreventionCPUThresholdPercent(_ percent: Int) -> Int {
        min(max(percent, minimumSleepPreventionCPUThresholdPercent), maximumSleepPreventionCPUThresholdPercent)
    }

    static func sleepPreventionNetworkThresholdKBPerSecond(defaults: UserDefaults = .standard) -> Int {
        guard defaults.object(forKey: sleepPreventionNetworkThresholdKBPerSecondKey) != nil else {
            return defaultSleepPreventionNetworkThresholdKBPerSecond
        }
        return normalizedSleepPreventionNetworkThresholdKBPerSecond(
            defaults.integer(forKey: sleepPreventionNetworkThresholdKBPerSecondKey)
        )
    }

    static func setSleepPreventionNetworkThresholdKBPerSecond(_ kbPerSecond: Int, defaults: UserDefaults = .standard) {
        defaults.set(
            normalizedSleepPreventionNetworkThresholdKBPerSecond(kbPerSecond),
            forKey: sleepPreventionNetworkThresholdKBPerSecondKey
        )
    }

    static func normalizedSleepPreventionNetworkThresholdKBPerSecond(_ kbPerSecond: Int) -> Int {
        min(
            max(kbPerSecond, minimumSleepPreventionNetworkThresholdKBPerSecond),
            maximumSleepPreventionNetworkThresholdKBPerSecond
        )
    }

    static func sleepPreventionAppMatchText(defaults: UserDefaults = .standard) -> String {
        let rawValue = defaults.string(forKey: sleepPreventionAppMatchTextKey) ?? defaultSleepPreventionAppMatchText
        return normalizedSleepPreventionAppMatchText(rawValue)
    }

    static func setSleepPreventionAppMatchText(_ text: String, defaults: UserDefaults = .standard) {
        defaults.set(text.trimmingCharacters(in: .whitespacesAndNewlines), forKey: sleepPreventionAppMatchTextKey)
    }

    static func normalizedSleepPreventionAppMatchText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultSleepPreventionAppMatchText : trimmed
    }

    static func sleepPreventionPreventDisplaySleep(defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: sleepPreventionPreventDisplaySleepKey) != nil else {
            return defaultSleepPreventionPreventDisplaySleep
        }
        return defaults.bool(forKey: sleepPreventionPreventDisplaySleepKey)
    }

    static func setSleepPreventionPreventDisplaySleep(_ isEnabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(isEnabled, forKey: sleepPreventionPreventDisplaySleepKey)
    }

    static func sleepPreventionPreventClosedLidSleep(defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: sleepPreventionPreventClosedLidSleepKey) != nil else {
            return defaultSleepPreventionPreventClosedLidSleep
        }
        return defaults.bool(forKey: sleepPreventionPreventClosedLidSleepKey)
    }

    static func setSleepPreventionPreventClosedLidSleep(_ isEnabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(isEnabled, forKey: sleepPreventionPreventClosedLidSleepKey)
    }

    static func sleepPreventionDisableScreenLock(defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: sleepPreventionDisableScreenLockKey) != nil else {
            return defaultSleepPreventionDisableScreenLock
        }
        return defaults.bool(forKey: sleepPreventionDisableScreenLockKey)
    }

    static func setSleepPreventionDisableScreenLock(_ isEnabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(isEnabled, forKey: sleepPreventionDisableScreenLockKey)
    }

    static func setDesktopPetEnabled(_ isEnabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(isEnabled, forKey: desktopPetEnabledKey)
    }

    static func setSleepPreventionEnabled(_ isEnabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(isEnabled ? SleepPreventionControlMode.time.rawValue : SleepPreventionControlMode.off.rawValue, forKey: sleepPreventionControlModeKey)
        defaults.set(isEnabled, forKey: sleepPreventionEnabledKey)
        if isEnabled {
            refreshSleepPreventionEndDate(defaults: defaults)
        } else {
            defaults.removeObject(forKey: sleepPreventionEndsAtKey)
            clearAutomaticSleepPreventionTriggers(defaults: defaults)
        }
    }

    static func setSleepPreventionControlMode(
        _ mode: SleepPreventionControlMode,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(mode.rawValue, forKey: sleepPreventionControlModeKey)

        switch mode {
        case .off:
            defaults.set(false, forKey: sleepPreventionEnabledKey)
            defaults.removeObject(forKey: sleepPreventionEndsAtKey)
            clearAutomaticSleepPreventionTriggers(defaults: defaults)
        case .time:
            clearAutomaticSleepPreventionTriggers(defaults: defaults)
            defaults.set(true, forKey: sleepPreventionEnabledKey)
            refreshSleepPreventionEndDate(defaults: defaults)
        case .condition:
            defaults.set(false, forKey: sleepPreventionEnabledKey)
            defaults.removeObject(forKey: sleepPreventionEndsAtKey)
        }
    }

    static func setSleepPreventionMode(_ mode: SleepPreventionMode, defaults: UserDefaults = .standard) {
        switch mode {
        case .off:
            setSleepPreventionControlMode(.off, defaults: defaults)
        case .always:
            defaults.set(SleepPreventionSessionPreset.indefinite.rawValue, forKey: sleepPreventionSessionPresetKey)
            setSleepPreventionControlMode(.time, defaults: defaults)
        case .charging:
            clearAutomaticSleepPreventionTriggers(defaults: defaults)
            setSleepPreventionControlMode(.condition, defaults: defaults)
            setSleepPreventionPowerAdapterTrigger(true, defaults: defaults)
        case .timed:
            let currentPreset = SleepPreventionSessionPreset(rawValue: defaults.string(forKey: sleepPreventionSessionPresetKey) ?? "") ?? defaultSleepPreventionSessionPreset
            if currentPreset.durationMinutes == nil {
                defaults.set(SleepPreventionSessionPreset.oneHour.rawValue, forKey: sleepPreventionSessionPresetKey)
            }
            setSleepPreventionControlMode(.time, defaults: defaults)
        case .application:
            clearAutomaticSleepPreventionTriggers(defaults: defaults)
            setSleepPreventionControlMode(.condition, defaults: defaults)
            setSleepPreventionCodexAppTrigger(true, defaults: defaults)
        case .condition:
            setSleepPreventionControlMode(.condition, defaults: defaults)
        }
    }

    static func setSleepPreventionSessionPreset(
        _ preset: SleepPreventionSessionPreset,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(preset.rawValue, forKey: sleepPreventionSessionPresetKey)
        if defaults.bool(forKey: sleepPreventionEnabledKey) {
            refreshSleepPreventionEndDate(defaults: defaults)
        }
    }

    static func expireSleepPreventionIfNeeded(now: Date = Date(), defaults: UserDefaults = .standard) {
        guard defaults.bool(forKey: sleepPreventionEnabledKey),
              defaults.object(forKey: sleepPreventionEndsAtKey) != nil else {
            return
        }

        let endsAt = Date(timeIntervalSince1970: defaults.double(forKey: sleepPreventionEndsAtKey))
        if now >= endsAt {
            setSleepPreventionEnabled(false, defaults: defaults)
        }
    }

    static func setSleepPreventionPowerAdapterTrigger(_ isEnabled: Bool, defaults: UserDefaults = .standard) {
        setConditionControlMode(defaults: defaults)
        defaults.set(isEnabled, forKey: sleepPreventionPowerAdapterTriggerKey)
    }

    static func setSleepPreventionCodexAppTrigger(_ isEnabled: Bool, defaults: UserDefaults = .standard) {
        setConditionControlMode(defaults: defaults)
        defaults.set(isEnabled, forKey: sleepPreventionCodexAppTriggerKey)
    }

    static func setSleepPreventionChargingBelowThresholdTrigger(_ isEnabled: Bool, defaults: UserDefaults = .standard) {
        setConditionControlMode(defaults: defaults)
        defaults.set(isEnabled, forKey: sleepPreventionChargingBelowThresholdTriggerKey)
    }

    static func setSleepPreventionCPUThresholdTrigger(_ isEnabled: Bool, defaults: UserDefaults = .standard) {
        setConditionControlMode(defaults: defaults)
        defaults.set(isEnabled, forKey: sleepPreventionCPUThresholdTriggerKey)
    }

    static func setSleepPreventionNetworkActivityTrigger(_ isEnabled: Bool, defaults: UserDefaults = .standard) {
        setConditionControlMode(defaults: defaults)
        defaults.set(isEnabled, forKey: sleepPreventionNetworkActivityTriggerKey)
    }

    static func setSleepPreventionExternalVolumeTrigger(_ isEnabled: Bool, defaults: UserDefaults = .standard) {
        setConditionControlMode(defaults: defaults)
        defaults.set(isEnabled, forKey: sleepPreventionExternalVolumeTriggerKey)
    }

    private static func setConditionControlMode(defaults: UserDefaults) {
        defaults.set(SleepPreventionControlMode.condition.rawValue, forKey: sleepPreventionControlModeKey)
        defaults.set(false, forKey: sleepPreventionEnabledKey)
        defaults.removeObject(forKey: sleepPreventionEndsAtKey)
    }

    private static func clearAutomaticSleepPreventionTriggers(defaults: UserDefaults) {
        defaults.set(false, forKey: sleepPreventionPowerAdapterTriggerKey)
        defaults.set(false, forKey: sleepPreventionCodexAppTriggerKey)
        defaults.set(false, forKey: sleepPreventionChargingBelowThresholdTriggerKey)
        defaults.set(false, forKey: sleepPreventionCPUThresholdTriggerKey)
        defaults.set(false, forKey: sleepPreventionNetworkActivityTriggerKey)
        defaults.set(false, forKey: sleepPreventionExternalVolumeTriggerKey)
    }

    private static func hasAutomaticSleepPreventionTrigger(defaults: UserDefaults) -> Bool {
        defaults.bool(forKey: sleepPreventionPowerAdapterTriggerKey)
            || defaults.bool(forKey: sleepPreventionCodexAppTriggerKey)
            || defaults.bool(forKey: sleepPreventionChargingBelowThresholdTriggerKey)
            || defaults.bool(forKey: sleepPreventionCPUThresholdTriggerKey)
            || defaults.bool(forKey: sleepPreventionNetworkActivityTriggerKey)
            || defaults.bool(forKey: sleepPreventionExternalVolumeTriggerKey)
    }

    private static func refreshSleepPreventionEndDate(defaults: UserDefaults) {
        let preset = SleepPreventionSessionPreset(rawValue: defaults.string(forKey: sleepPreventionSessionPresetKey) ?? "") ?? defaultSleepPreventionSessionPreset

        guard let minutes = preset.durationMinutes else {
            defaults.removeObject(forKey: sleepPreventionEndsAtKey)
            return
        }

        defaults.set(Date().addingTimeInterval(TimeInterval(minutes * 60)).timeIntervalSince1970, forKey: sleepPreventionEndsAtKey)
    }

    static func desktopPetOrigin(defaults: UserDefaults = .standard) -> NSPoint? {
        guard defaults.object(forKey: desktopPetOriginXKey) != nil,
              defaults.object(forKey: desktopPetOriginYKey) != nil else {
            return nil
        }

        return NSPoint(
            x: defaults.double(forKey: desktopPetOriginXKey),
            y: defaults.double(forKey: desktopPetOriginYKey)
        )
    }

    static func setDesktopPetOrigin(_ origin: NSPoint, defaults: UserDefaults = .standard) {
        defaults.set(origin.x, forKey: desktopPetOriginXKey)
        defaults.set(origin.y, forKey: desktopPetOriginYKey)
    }
}

enum UsageDisplayBasis: String, CaseIterable, Identifiable {
    case max
    case fiveHour
    case weekly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .max:
            "최대"
        case .fiveHour:
            "5시간"
        case .weekly:
            "주간"
        }
    }
}

enum SleepPreventionSessionPreset: String, CaseIterable, Identifiable {
    case indefinite
    case thirtyMinutes
    case oneHour
    case twoHours

    static let timedCases: [SleepPreventionSessionPreset] = [.thirtyMinutes, .oneHour, .twoHours]

    var id: String { rawValue }

    var durationMinutes: Int? {
        switch self {
        case .indefinite:
            nil
        case .thirtyMinutes:
            30
        case .oneHour:
            60
        case .twoHours:
            120
        }
    }

    var label: String {
        switch self {
        case .indefinite:
            "계속"
        case .thirtyMinutes:
            "30분"
        case .oneHour:
            "1시간"
        case .twoHours:
            "2시간"
        }
    }
}

enum SleepPreventionControlMode: String, CaseIterable, Identifiable {
    case off
    case time
    case condition

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off:
            "끔"
        case .time:
            "시간 제어"
        case .condition:
            "상태 기준"
        }
    }
}

enum SleepPreventionMode: String, CaseIterable, Identifiable {
    case off
    case always
    case charging
    case timed
    case application
    case condition

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off:
            "끔"
        case .always:
            "항상 금지"
        case .charging:
            "충전 중 금지"
        case .timed:
            "시간 기준 금지"
        case .application:
            "Codex 앱 실행 중"
        case .condition:
            "상태 기준 제어"
        }
    }
}
