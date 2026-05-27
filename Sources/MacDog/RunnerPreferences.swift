import Foundation
import AppKit

struct RunnerPreferences: Equatable {
    static let displayBasisKey = "displayBasis"
    static let reducedMotionKey = "reducedMotion"
    static let animationPausedKey = "animationPaused"
    static let desktopPetEnabledKey = "desktopPetEnabled"
    static let sleepPreventionEnabledKey = "sleepPreventionEnabled"
    static let sleepPreventionSessionPresetKey = "sleepPreventionSessionPreset"
    static let sleepPreventionEndsAtKey = "sleepPreventionEndsAt"
    static let desktopPetOriginXKey = "desktopPetOriginX"
    static let desktopPetOriginYKey = "desktopPetOriginY"
    static let defaultDisplayBasis = UsageDisplayBasis.weekly
    static let defaultSleepPreventionSessionPreset = SleepPreventionSessionPreset.indefinite

    static func registerDefaults(defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            displayBasisKey: defaultDisplayBasis.rawValue,
            reducedMotionKey: false,
            animationPausedKey: false,
            desktopPetEnabledKey: false,
            sleepPreventionEnabledKey: false,
            sleepPreventionSessionPresetKey: defaultSleepPreventionSessionPreset.rawValue
        ])
    }

    let displayBasis: UsageDisplayBasis
    let reducedMotion: Bool
    let animationPaused: Bool
    let desktopPetEnabled: Bool
    let sleepPreventionEnabled: Bool
    let sleepPreventionSessionPreset: SleepPreventionSessionPreset
    let sleepPreventionEndsAt: Date?

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

    static func setDesktopPetEnabled(_ isEnabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(isEnabled, forKey: desktopPetEnabledKey)
    }

    static func setSleepPreventionEnabled(_ isEnabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(isEnabled, forKey: sleepPreventionEnabledKey)
        if isEnabled {
            refreshSleepPreventionEndDate(defaults: defaults)
        } else {
            defaults.removeObject(forKey: sleepPreventionEndsAtKey)
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
