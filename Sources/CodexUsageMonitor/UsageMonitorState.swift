import CodexUsageCore
import Foundation

struct UsageMonitorState: Equatable {
    static let empty = UsageMonitorState(report: nil, cacheSnapshot: nil, errorMessage: nil)

    let report: CodexUsageReport?
    let cacheSnapshot: CodexUsageCacheSnapshot?
    let errorMessage: String?
    let displayBasis: UsageDisplayBasis
    let reducedMotion: Bool
    let isRefreshing: Bool

    init(
        report: CodexUsageReport?,
        cacheSnapshot: CodexUsageCacheSnapshot?,
        errorMessage: String?,
        displayBasis: UsageDisplayBasis = .max,
        reducedMotion: Bool = false,
        isRefreshing: Bool = false
    ) {
        self.report = report
        self.cacheSnapshot = cacheSnapshot
        self.errorMessage = errorMessage
        self.displayBasis = displayBasis
        self.reducedMotion = reducedMotion
        self.isRefreshing = isRefreshing
    }

    func withRefreshing(_ isRefreshing: Bool) -> UsageMonitorState {
        UsageMonitorState(
            report: report,
            cacheSnapshot: cacheSnapshot,
            errorMessage: errorMessage,
            displayBasis: displayBasis,
            reducedMotion: reducedMotion,
            isRefreshing: isRefreshing
        )
    }

    var codexLimit: UsageLimitReport? {
        report?.codexLimit
    }

    var phase: UsagePressurePhase {
        if codexLimit?.rateLimitReachedType != nil {
            return .limit
        }
        return UsagePressurePhase(usedPercent: selectedUsedPercent)
    }

    var selectedUsedPercent: Double {
        guard let limit = codexLimit else { return 0 }

        switch displayBasis {
        case .max:
            return limit.maxUsedPercent
        case .fiveHour:
            return limit.fiveHour?.usedPercent ?? 0
        case .weekly:
            return limit.weekly?.usedPercent ?? 0
        }
    }

    var isStale: Bool {
        cacheSnapshot?.isStale() ?? false
    }

    var sourceLabel: String {
        if isRefreshing {
            return "refreshing"
        }
        if cacheSnapshot != nil {
            return isStale ? "cache stale" : "cache"
        }
        if report != nil {
            return "live"
        }
        return "unavailable"
    }

    var toolTip: String {
        if isRefreshing, codexLimit == nil {
            return "Codex Usage refreshing"
        }
        guard let limit = codexLimit else {
            return "Codex Usage unavailable"
        }
        let fiveHour = limit.fiveHour.map { "\(Self.percent($0.usedPercent))% 5h" } ?? "5h unavailable"
        let weekly = limit.weekly.map { "\(Self.percent($0.usedPercent))% weekly" } ?? "weekly unavailable"
        return "Codex Usage: \(fiveHour), \(weekly), basis \(displayBasis.label)"
    }

    static func percent(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}

enum UsagePressurePhase: String, Equatable {
    case calm
    case active
    case fast
    case sprint
    case limit

    init(usedPercent: Double) {
        switch usedPercent {
        case 100...:
            self = .limit
        case 95..<100:
            self = .sprint
        case 80..<95:
            self = .fast
        case 50..<80:
            self = .active
        default:
            self = .calm
        }
    }

    var frameInterval: TimeInterval {
        switch self {
        case .calm:
            0.55
        case .active:
            0.32
        case .fast:
            0.18
        case .sprint:
            0.1
        case .limit:
            0.75
        }
    }

    func frameInterval(reducedMotion: Bool) -> TimeInterval {
        reducedMotion ? 1.5 : frameInterval
    }

    var label: String {
        switch self {
        case .calm:
            "Calm"
        case .active:
            "Active"
        case .fast:
            "Fast"
        case .sprint:
            "Sprint"
        case .limit:
            "Limit"
        }
    }
}
