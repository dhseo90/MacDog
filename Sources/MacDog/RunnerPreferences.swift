import Foundation
import AppKit

struct RunnerPreferences: Equatable {
    static let displayBasisKey = "displayBasis"
    static let reducedMotionKey = "reducedMotion"
    static let animationPausedKey = "animationPaused"
    static let desktopPetEnabledKey = "desktopPetEnabled"
    static let desktopPetOriginXKey = "desktopPetOriginX"
    static let desktopPetOriginYKey = "desktopPetOriginY"
    static let defaultDisplayBasis = UsageDisplayBasis.weekly

    static func registerDefaults(defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            displayBasisKey: defaultDisplayBasis.rawValue,
            reducedMotionKey: false,
            animationPausedKey: false,
            desktopPetEnabledKey: false
        ])
    }

    let displayBasis: UsageDisplayBasis
    let reducedMotion: Bool
    let animationPaused: Bool
    let desktopPetEnabled: Bool

    init(defaults: UserDefaults = .standard) {
        self.displayBasis = UsageDisplayBasis(rawValue: defaults.string(forKey: Self.displayBasisKey) ?? "") ?? Self.defaultDisplayBasis
        self.reducedMotion = defaults.bool(forKey: Self.reducedMotionKey)
        self.animationPaused = defaults.bool(forKey: Self.animationPausedKey)
        self.desktopPetEnabled = defaults.bool(forKey: Self.desktopPetEnabledKey)
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
