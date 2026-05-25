import Foundation

struct RunnerPreferences: Equatable {
    static let themeKey = "runnerTheme"
    static let displayBasisKey = "displayBasis"
    static let reducedMotionKey = "reducedMotion"

    let theme: RunnerTheme
    let displayBasis: UsageDisplayBasis
    let reducedMotion: Bool

    init(defaults: UserDefaults = .standard) {
        self.theme = RunnerTheme(rawValue: defaults.string(forKey: Self.themeKey) ?? "") ?? .runner
        self.displayBasis = UsageDisplayBasis(rawValue: defaults.string(forKey: Self.displayBasisKey) ?? "") ?? .max
        self.reducedMotion = defaults.bool(forKey: Self.reducedMotionKey)
    }
}

enum RunnerTheme: String, CaseIterable, Identifiable {
    case runner
    case spark
    case pulse

    var id: String { rawValue }

    var label: String {
        switch self {
        case .runner:
            "Runner"
        case .spark:
            "Spark"
        case .pulse:
            "Pulse"
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
            "Max"
        case .fiveHour:
            "5h"
        case .weekly:
            "Weekly"
        }
    }
}

