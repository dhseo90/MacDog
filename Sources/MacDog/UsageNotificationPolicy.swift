import CodexUsageCore
import Foundation

struct UsageNotificationPolicy: Equatable {
    static let highUsageThresholdPercent: Double = 80
    static let approachingLimitThresholdPercent: Double = 95
    static let limitReachedThresholdPercent: Double = 100
    static let resetSoonLeadTime: TimeInterval = 30 * 60

    func candidates(
        for state: UsageMonitorState,
        now: Date = Date()
    ) -> [UsageNotificationCandidate] {
        guard let limit = state.codexLimit else { return [] }

        let windows = notificationWindows(for: limit)
        let usageCandidates = usageThresholdCandidates(
            for: windows,
            hasReachedLimit: state.report?.rateLimitReachedType != nil || limit.rateLimitReachedType != nil
        )
        let resetSoonCandidates = windows.compactMap { resetSoonCandidate(for: $0, now: now) }

        return usageCandidates + resetSoonCandidates
    }

    private func usageThresholdCandidates(
        for windows: [UsageNotificationWindowSnapshot],
        hasReachedLimit: Bool
    ) -> [UsageNotificationCandidate] {
        let limitWindows = windows.filter { $0.report.usedPercent >= Self.limitReachedThresholdPercent }
        if !limitWindows.isEmpty {
            return limitWindows.map { candidate(event: .limitReached, snapshot: $0) }
        }

        if hasReachedLimit, let highestWindow = windows.max(by: { $0.report.usedPercent < $1.report.usedPercent }) {
            return [candidate(event: .limitReached, snapshot: highestWindow)]
        }

        return windows.compactMap { snapshot in
            switch snapshot.report.usedPercent {
            case Self.approachingLimitThresholdPercent..<Self.limitReachedThresholdPercent:
                candidate(event: .approachingLimit, snapshot: snapshot)
            case Self.highUsageThresholdPercent..<Self.approachingLimitThresholdPercent:
                candidate(event: .highUsage, snapshot: snapshot)
            default:
                nil
            }
        }
    }

    private func resetSoonCandidate(
        for snapshot: UsageNotificationWindowSnapshot,
        now: Date
    ) -> UsageNotificationCandidate? {
        guard snapshot.report.usedPercent >= Self.highUsageThresholdPercent,
              let resetsAt = snapshot.report.resetsAt else {
            return nil
        }

        let remaining = Date(timeIntervalSince1970: TimeInterval(resetsAt)).timeIntervalSince(now)
        guard remaining > 0, remaining <= Self.resetSoonLeadTime else {
            return nil
        }

        return candidate(event: .resetSoon, snapshot: snapshot)
    }

    private func candidate(
        event: UsageNotificationEvent,
        snapshot: UsageNotificationWindowSnapshot
    ) -> UsageNotificationCandidate {
        UsageNotificationCandidate(
            event: event,
            window: snapshot.window,
            usedPercent: snapshot.report.usedPercent,
            resetsAt: snapshot.report.resetsAt
        )
    }

    private func notificationWindows(for limit: UsageLimitReport) -> [UsageNotificationWindowSnapshot] {
        [
            limit.fiveHour.map {
                UsageNotificationWindowSnapshot(window: .fiveHour, report: $0)
            },
            limit.weekly.map {
                UsageNotificationWindowSnapshot(window: .weekly, report: $0)
            }
        ]
        .compactMap(\.self)
    }
}

struct UsageNotificationCandidate: Equatable, Sendable {
    let event: UsageNotificationEvent
    let window: UsageNotificationWindow
    let usedPercent: Double
    let resetsAt: Int?

    var dedupeKey: UsageNotificationDedupeKey {
        UsageNotificationDedupeKey(event: event, window: window, resetsAt: resetsAt)
    }
}

enum UsageNotificationEvent: String, Equatable, Sendable {
    case highUsage
    case approachingLimit
    case limitReached
    case resetSoon
}

enum UsageNotificationWindow: String, Equatable, Sendable {
    case fiveHour
    case weekly

    var label: String {
        switch self {
        case .fiveHour:
            "5시간"
        case .weekly:
            "주간"
        }
    }
}

struct UsageNotificationDedupeKey: Hashable, Sendable {
    let event: UsageNotificationEvent
    let window: UsageNotificationWindow
    let resetsAt: Int?

    var rawValue: String {
        "usage.\(event.rawValue).\(window.rawValue).reset.\(resetsAt.map(String.init) ?? "unknown")"
    }
}

struct UsageNotificationDedupeLedger: Equatable, Sendable {
    let deliveredKeys: [UsageNotificationDedupeKey]

    init(deliveredKeys: [UsageNotificationDedupeKey] = []) {
        self.deliveredKeys = Self.uniqued(deliveredKeys)
    }

    func newKeys(_ keys: [UsageNotificationDedupeKey]) -> [UsageNotificationDedupeKey] {
        keys.filter { !deliveredKeys.contains($0) }
    }

    func recording(_ keys: [UsageNotificationDedupeKey]) -> UsageNotificationDedupeLedger {
        UsageNotificationDedupeLedger(deliveredKeys: deliveredKeys + keys)
    }

    private static func uniqued(_ keys: [UsageNotificationDedupeKey]) -> [UsageNotificationDedupeKey] {
        var seen: Set<UsageNotificationDedupeKey> = []
        var result: [UsageNotificationDedupeKey] = []

        for key in keys where !seen.contains(key) {
            seen.insert(key)
            result.append(key)
        }

        return result
    }
}

private struct UsageNotificationWindowSnapshot {
    let window: UsageNotificationWindow
    let report: UsageWindowReport
}
