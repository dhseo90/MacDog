import CodexUsageCore
import Foundation
import MacDogPrivilegedHelperSupport

struct UsageMonitorState: Equatable {
    static let empty = UsageMonitorState(report: nil, cacheSnapshot: nil, errorMessage: nil)

    let report: CodexUsageReport?
    let cacheSnapshot: CodexUsageCacheSnapshot?
    let errorMessage: String?
    let displayBasis: UsageDisplayBasis
    let reducedMotion: Bool
    let animationPaused: Bool
    let isRefreshing: Bool
    let systemMetrics: SystemMetricsSnapshot
    let systemMetricsHistory: SystemMetricsHistory
    let sleepPreventionStatus: SleepPreventionStatus
    let sleepPreventionTriggerStatus: SleepPreventionTriggerStatus
    let privilegedHelperInstallSnapshot: PrivilegedHelperInstallSnapshot

    init(
        report: CodexUsageReport?,
        cacheSnapshot: CodexUsageCacheSnapshot?,
        errorMessage: String?,
        displayBasis: UsageDisplayBasis = .max,
        reducedMotion: Bool = false,
        animationPaused: Bool = false,
        isRefreshing: Bool = false,
        systemMetrics: SystemMetricsSnapshot = .capture(),
        systemMetricsHistory: SystemMetricsHistory = .empty,
        sleepPreventionStatus: SleepPreventionStatus = .disabled,
        sleepPreventionTriggerStatus: SleepPreventionTriggerStatus = .disabled,
        privilegedHelperInstallSnapshot: PrivilegedHelperInstallSnapshot = .missing
    ) {
        self.report = report
        self.cacheSnapshot = cacheSnapshot
        self.errorMessage = errorMessage
        self.displayBasis = displayBasis
        self.reducedMotion = reducedMotion
        self.animationPaused = animationPaused
        self.isRefreshing = isRefreshing
        self.systemMetrics = systemMetrics
        self.systemMetricsHistory = systemMetricsHistory
        self.sleepPreventionStatus = sleepPreventionStatus
        self.sleepPreventionTriggerStatus = sleepPreventionTriggerStatus
        self.privilegedHelperInstallSnapshot = privilegedHelperInstallSnapshot
    }

    func withRefreshing(_ isRefreshing: Bool) -> UsageMonitorState {
        UsageMonitorState(
            report: report,
            cacheSnapshot: cacheSnapshot,
            errorMessage: errorMessage,
            displayBasis: displayBasis,
            reducedMotion: reducedMotion,
            animationPaused: animationPaused,
            isRefreshing: isRefreshing,
            systemMetrics: systemMetrics,
            systemMetricsHistory: systemMetricsHistory,
            sleepPreventionStatus: sleepPreventionStatus,
            sleepPreventionTriggerStatus: sleepPreventionTriggerStatus,
            privilegedHelperInstallSnapshot: privilegedHelperInstallSnapshot
        )
    }

    func withSystemMetrics(
        _ systemMetrics: SystemMetricsSnapshot,
        systemMetricsHistory: SystemMetricsHistory? = nil,
        sleepPreventionStatus: SleepPreventionStatus,
        sleepPreventionTriggerStatus: SleepPreventionTriggerStatus,
        privilegedHelperInstallSnapshot: PrivilegedHelperInstallSnapshot
    ) -> UsageMonitorState {
        UsageMonitorState(
            report: report,
            cacheSnapshot: cacheSnapshot,
            errorMessage: errorMessage,
            displayBasis: displayBasis,
            reducedMotion: reducedMotion,
            animationPaused: animationPaused,
            isRefreshing: isRefreshing,
            systemMetrics: systemMetrics,
            systemMetricsHistory: systemMetricsHistory ?? self.systemMetricsHistory,
            sleepPreventionStatus: sleepPreventionStatus,
            sleepPreventionTriggerStatus: sleepPreventionTriggerStatus,
            privilegedHelperInstallSnapshot: privilegedHelperInstallSnapshot
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

    var selectedWindowStatus: UsageWindowStatus? {
        guard let limit = codexLimit else { return nil }

        switch displayBasis {
        case .max:
            return [
                UsageWindowStatus(label: "5시간", window: limit.fiveHour),
                UsageWindowStatus(label: "주간", window: limit.weekly)
            ]
            .compactMap(\.self)
            .max { $0.window.usedPercent < $1.window.usedPercent }
        case .fiveHour:
            return UsageWindowStatus(label: "5시간", window: limit.fiveHour)
        case .weekly:
            return UsageWindowStatus(label: "주간", window: limit.weekly)
        }
    }

    var highUsageMessage: String? {
        if phase == .limit {
            if let status = selectedWindowStatus {
                return "한도 도달 · \(status.summary)"
            }
            return "한도 도달"
        }

        guard let status = selectedWindowStatus else { return nil }

        switch phase {
        case .fast:
            return "사용량 높음 · \(status.summary)"
        case .sprint:
            return "한도 임박 · \(status.remainingSummary)"
        case .calm, .active, .limit:
            return nil
        }
    }

    var isStale: Bool {
        cacheSnapshot?.isStale() ?? false
    }

    var sourceLabel: String {
        if isRefreshing {
            return "새로고침 중"
        }
        if cacheSnapshot != nil {
            return isStale ? "오래된 캐시" : "캐시"
        }
        if report != nil {
            return "실시간"
        }
        return "확인 불가"
    }

    var lastUpdatedSummary: String {
        let timestamp = cacheSnapshot?.cachedAt ?? report?.generatedAt
        guard let timestamp else { return "알 수 없음" }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        return date.formatted(date: .omitted, time: .shortened)
    }

    var toolTip: String {
        if isRefreshing, codexLimit == nil {
            return "코덱스 사용량 새로고침 중"
        }
        guard let limit = codexLimit else {
            return "코덱스 사용량 확인 불가"
        }
        let fiveHour = limit.fiveHour.map { "\(Self.percent($0.usedPercent))% 5시간" } ?? "5시간 확인 불가"
        let weekly = limit.weekly.map { "\(Self.percent($0.usedPercent))% 주간" } ?? "주간 확인 불가"
        let motion = animationPaused ? ", 일시 정지" : ""
        return "코덱스 사용량: \(fiveHour), \(weekly), 기준 \(displayBasis.label)\(motion)"
    }

    static func percent(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}

struct UsageWindowStatus: Equatable {
    let label: String
    let window: UsageWindowReport

    init?(label: String, window: UsageWindowReport?) {
        guard let window else { return nil }
        self.label = label
        self.window = window
    }

    var summary: String {
        "\(label) \(UsageMonitorState.percent(window.usedPercent))% 사용 / \(UsageMonitorState.percent(window.remainingPercent))% 남음"
    }

    var remainingSummary: String {
        "\(label) \(UsageMonitorState.percent(window.remainingPercent))% 남음"
    }
}

enum UsagePressurePhase: String, Equatable {
    case calm
    case active
    case fast
    case sprint
    case limit

    static let thresholdSummary = "50% 활발 · 80% 빠름 · 95% 질주"

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
            "여유"
        case .active:
            "활발"
        case .fast:
            "빠름"
        case .sprint:
            "질주"
        case .limit:
            "한도"
        }
    }

    var statusLabel: String {
        switch self {
        case .calm:
            "여유"
        case .active:
            "활발"
        case .fast:
            "사용량 높음"
        case .sprint:
            "한도 임박"
        case .limit:
            "한도 도달"
        }
    }
}
