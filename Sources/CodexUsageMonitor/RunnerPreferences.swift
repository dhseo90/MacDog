import Foundation

struct RunnerPreferences: Equatable {
    static let displayBasisKey = "displayBasis"
    static let reducedMotionKey = "reducedMotion"
    static let defaultDisplayBasis = UsageDisplayBasis.weekly

    static func registerDefaults(defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            displayBasisKey: defaultDisplayBasis.rawValue,
            reducedMotionKey: false
        ])
    }

    let displayBasis: UsageDisplayBasis
    let reducedMotion: Bool

    init(defaults: UserDefaults = .standard) {
        self.displayBasis = UsageDisplayBasis(rawValue: defaults.string(forKey: Self.displayBasisKey) ?? "") ?? Self.defaultDisplayBasis
        self.reducedMotion = defaults.bool(forKey: Self.reducedMotionKey)
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
            "Highest"
        case .fiveHour:
            "5h"
        case .weekly:
            "Weekly"
        }
    }
}
