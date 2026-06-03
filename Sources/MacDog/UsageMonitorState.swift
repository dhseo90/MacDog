import CodexUsageCore
import Foundation
import MacDogPrivilegedHelperSupport

struct UsageMonitorState: Equatable {
    static let empty = UsageMonitorState(
        report: nil,
        cacheSnapshot: nil,
        errorMessage: nil,
        systemMetrics: .unavailable
    )

    let report: CodexUsageReport?
    let cacheSnapshot: CodexUsageCacheSnapshot?
    let weeklyUsageHistory: CodexUsageWeeklyHistory
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
        weeklyUsageHistory: CodexUsageWeeklyHistory = .empty,
        errorMessage: String?,
        displayBasis: UsageDisplayBasis = .max,
        reducedMotion: Bool = false,
        animationPaused: Bool = false,
        isRefreshing: Bool = false,
        systemMetrics: SystemMetricsSnapshot = .unavailable,
        systemMetricsHistory: SystemMetricsHistory = .empty,
        sleepPreventionStatus: SleepPreventionStatus = .disabled,
        sleepPreventionTriggerStatus: SleepPreventionTriggerStatus = .disabled,
        privilegedHelperInstallSnapshot: PrivilegedHelperInstallSnapshot = .missing
    ) {
        self.report = report
        self.cacheSnapshot = cacheSnapshot
        self.weeklyUsageHistory = weeklyUsageHistory
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
            weeklyUsageHistory: weeklyUsageHistory,
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
            weeklyUsageHistory: weeklyUsageHistory,
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

    var petReaction: PetStatusReaction {
        if (systemMetrics.cpuLoadPercent ?? 0) >= PetStatusReaction.systemLoadThresholdPercent ||
            (systemMetrics.memoryUsedPercent ?? 0) >= PetStatusReaction.systemLoadThresholdPercent {
            return .systemLoad
        }

        let battery = systemMetrics.battery
        if battery.isPresent,
           let percent = battery.percent,
           percent <= PetStatusReaction.lowBatteryThresholdPercent,
           battery.isConnectedToPower != true {
            return .lowBattery
        }

        if battery.isPresent, battery.isCharging == true {
            return .charging
        }

        return .normal
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
        if codexLimit != nil {
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

enum PetStatusReaction: Equatable {
    static let systemLoadThresholdPercent: Double = 85
    static let lowBatteryThresholdPercent = 20

    case normal
    case systemLoad
    case lowBattery
    case charging

    var pausesRoaming: Bool {
        switch self {
        case .normal:
            false
        case .systemLoad, .lowBattery, .charging:
            true
        }
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

    static func resetSummary(
        resetsAt: Int?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        guard let resetsAt else { return "초기화 시각 알 수 없음" }
        let resetDate = Date(timeIntervalSince1970: TimeInterval(resetsAt))
        let time = compactResetTime(resetDate, now: now, calendar: calendar)
        let remaining = resetRemainingSummary(until: resetDate, now: now)

        if remaining == "초기화 확인 중" {
            return "\(remaining) · \(time)"
        }
        return "초기화까지 \(remaining) · \(time)"
    }

    static func resetRemainingSummary(until resetDate: Date, now: Date = Date()) -> String {
        let seconds = Int(ceil(resetDate.timeIntervalSince(now)))
        guard seconds > 0 else { return "초기화 확인 중" }
        guard seconds >= 60 else { return "1분 미만 남음" }

        let minutes = Int(ceil(Double(seconds) / 60))
        guard minutes >= 60 else { return "\(minutes)분 남음" }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        guard hours >= 24 else {
            if remainingMinutes == 0 {
                return "\(hours)시간 남음"
            }
            return "\(hours)시간 \(remainingMinutes)분 남음"
        }

        let days = hours / 24
        let remainingHours = hours % 24
        if remainingHours == 0 {
            return "\(days)일 남음"
        }
        return "\(days)일 \(remainingHours)시간 남음"
    }

    private static func compactResetTime(
        _ resetDate: Date,
        now: Date,
        calendar inputCalendar: Calendar
    ) -> String {
        let calendar = inputCalendar
        let components = calendar.dateComponents([.month, .day, .hour, .minute], from: resetDate)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0

        if calendar.isDate(resetDate, inSameDayAs: now) {
            return String(format: "%02d:%02d", hour, minute)
        }

        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%d/%d %02d:%02d", month, day, hour, minute)
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
