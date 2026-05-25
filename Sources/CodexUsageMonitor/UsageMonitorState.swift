import CodexUsageCore
import Foundation

struct UsageMonitorState: Equatable {
    static let empty = UsageMonitorState(report: nil, cacheSnapshot: nil, errorMessage: nil)

    let report: CodexUsageReport?
    let cacheSnapshot: CodexUsageCacheSnapshot?
    let errorMessage: String?

    var codexLimit: UsageLimitReport? {
        report?.codexLimit
    }

    var phase: UsagePressurePhase {
        if codexLimit?.rateLimitReachedType != nil {
            return .limit
        }
        return UsagePressurePhase(usedPercent: codexLimit?.maxUsedPercent ?? 0)
    }

    var isStale: Bool {
        cacheSnapshot?.isStale() ?? false
    }

    var sourceLabel: String {
        if cacheSnapshot != nil {
            return isStale ? "cache stale" : "cache"
        }
        if report != nil {
            return "live"
        }
        return "unavailable"
    }

    var toolTip: String {
        guard let limit = codexLimit else {
            return "Codex Usage unavailable"
        }
        let fiveHour = limit.fiveHour.map { "\(Self.percent($0.usedPercent))% 5h" } ?? "5h unavailable"
        let weekly = limit.weekly.map { "\(Self.percent($0.usedPercent))% weekly" } ?? "weekly unavailable"
        return "Codex Usage: \(fiveHour), \(weekly)"
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

