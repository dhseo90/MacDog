import Foundation

struct RunnerPreferences: Equatable {
    static let themeKey = "runnerTheme"
    static let displayBasisKey = "displayBasis"
    static let reducedMotionKey = "reducedMotion"
    static let defaultTheme = RunnerTheme.pup
    static let defaultDisplayBasis = UsageDisplayBasis.weekly

    static func registerDefaults(defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            themeKey: defaultTheme.rawValue,
            displayBasisKey: defaultDisplayBasis.rawValue,
            reducedMotionKey: false
        ])
    }

    let theme: RunnerTheme
    let displayBasis: UsageDisplayBasis
    let reducedMotion: Bool

    init(defaults: UserDefaults = .standard) {
        self.theme = RunnerTheme(rawValue: defaults.string(forKey: Self.themeKey) ?? "") ?? Self.defaultTheme
        self.displayBasis = UsageDisplayBasis(rawValue: defaults.string(forKey: Self.displayBasisKey) ?? "") ?? Self.defaultDisplayBasis
        self.reducedMotion = defaults.bool(forKey: Self.reducedMotionKey)
    }
}

enum RunnerTheme: String, CaseIterable, Identifiable {
    case pup
    case spark
    case pulse

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pup:
            "Pup"
        case .spark:
            "Spark Pup"
        case .pulse:
            "Pulse Pup"
        }
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
