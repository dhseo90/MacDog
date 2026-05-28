import Foundation

struct PopoverMetricsRefreshPolicy: Equatable {
    static let localMetricsInterval: TimeInterval = 1
    static let localMetricsTolerance: TimeInterval = 0.15

    static func shouldRefreshLocalMetrics(for module: MacDogPopoverModule) -> Bool {
        switch module {
        case .mac, .sleep, .battery:
            true
        case .codex:
            false
        }
    }

    static func shouldRefreshLocalMetrics(forRawValue rawValue: String?) -> Bool {
        guard
            let rawValue,
            let module = MacDogPopoverModule(rawValue: rawValue)
        else { return false }

        return shouldRefreshLocalMetrics(for: module)
    }
}
