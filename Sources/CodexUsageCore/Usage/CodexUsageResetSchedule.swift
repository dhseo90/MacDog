import Foundation

public enum CodexUsageResetScheduleState: String, Equatable, Sendable {
    case ok
    case waiting
    case stale
    case error
    case protocolDrift
}

public enum CodexUsageResetScheduleTrustState: String, Equatable, Sendable {
    case fresh
    case stale
    case error
    case waiting
}

public enum CodexUsageResetScheduleEntryScope: String, Equatable, Sendable {
    case primary
    case advanced
}

public struct CodexUsageResetSchedule: Equatable, Sendable {
    public let state: CodexUsageResetScheduleState
    public let entries: [CodexUsageResetScheduleEntry]

    public init(
        state: CodexUsageResetScheduleState,
        entries: [CodexUsageResetScheduleEntry]
    ) {
        self.state = state
        self.entries = entries
    }

    public var primaryEntries: [CodexUsageResetScheduleEntry] {
        entries.filter { $0.scope == .primary }
    }

    public var advancedEntries: [CodexUsageResetScheduleEntry] {
        entries.filter { $0.scope == .advanced }
    }

    public var nextRecovery: CodexUsageResetScheduleEntry? {
        primaryEntries.first { $0.isNextRecovery }
    }

    public var trustSummary: String {
        switch state {
        case .ok:
            return "최신 기준"
        case .waiting:
            return "사용량 데이터 대기"
        case .stale:
            return "마지막 확인 기준"
        case .error:
            return "오류 상태 함께 표시"
        case .protocolDrift:
            return "필수 5시간/주간 window 확인 필요"
        }
    }

    public var summaryText: String {
        switch state {
        case .protocolDrift:
            return "필수 5시간/주간 window 확인 필요"
        case .waiting:
            return "회복 일정 대기"
        case .ok, .stale, .error:
            guard let nextRecovery else {
                return "회복 카드 \(primaryEntries.count)장"
            }
            return "회복 카드 \(primaryEntries.count)장 · 다음 \(nextRecovery.title) \(Self.relativeTime(nextRecovery.remainingSeconds))"
        }
    }

    private static func relativeTime(_ seconds: Int?) -> String {
        guard let seconds else { return "시각 확인 불가" }
        if seconds <= 0 { return "곧" }

        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        if hours > 0, minutes > 0 {
            return "\(hours)시간 \(minutes)분 후"
        }
        if hours > 0 {
            return "\(hours)시간 후"
        }
        return "\(max(minutes, 1))분 후"
    }
}

public struct CodexUsageResetScheduleEntry: Equatable, Identifiable, Sendable {
    public let id: String
    public let limitId: String
    public let limitName: String?
    public let title: String
    public let kind: UsageWindowKind
    public let scope: CodexUsageResetScheduleEntryScope
    public let windowDurationMins: Int?
    public let resetsAt: Int?
    public let remainingSeconds: Int?
    public let usedPercent: Double
    public let remainingPercent: Double
    public let trustState: CodexUsageResetScheduleTrustState
    public let isNextRecovery: Bool

    public init(
        id: String,
        limitId: String,
        limitName: String?,
        title: String,
        kind: UsageWindowKind,
        scope: CodexUsageResetScheduleEntryScope,
        windowDurationMins: Int?,
        resetsAt: Int?,
        remainingSeconds: Int?,
        usedPercent: Double,
        remainingPercent: Double,
        trustState: CodexUsageResetScheduleTrustState,
        isNextRecovery: Bool
    ) {
        self.id = id
        self.limitId = limitId
        self.limitName = limitName
        self.title = title
        self.kind = kind
        self.scope = scope
        self.windowDurationMins = windowDurationMins
        self.resetsAt = resetsAt
        self.remainingSeconds = remainingSeconds
        self.usedPercent = usedPercent
        self.remainingPercent = remainingPercent
        self.trustState = trustState
        self.isNextRecovery = isNextRecovery
    }
}

public struct CodexUsageResetScheduleBuilder: Sendable {
    public init() {}

    public func schedule(
        snapshot: CodexUsageCacheSnapshot?,
        now: Date = Date()
    ) -> CodexUsageResetSchedule {
        schedule(
            report: snapshot?.report,
            cacheState: cacheState(snapshot: snapshot, now: now),
            now: now
        )
    }

    public func schedule(
        report: CodexUsageReport?,
        now: Date = Date()
    ) -> CodexUsageResetSchedule {
        schedule(report: report, cacheState: .ok, now: now)
    }

    private func schedule(
        report: CodexUsageReport?,
        cacheState: CodexUsageResetScheduleState,
        now: Date
    ) -> CodexUsageResetSchedule {
        guard let report else {
            let state: CodexUsageResetScheduleState = switch cacheState {
            case .error:
                .error
            case .ok, .waiting, .stale, .protocolDrift:
                .waiting
            }
            return CodexUsageResetSchedule(state: state, entries: [])
        }
        guard let codex = report.limits["codex"], codex.hasRequiredCodexUsageWindows else {
            return CodexUsageResetSchedule(state: .protocolDrift, entries: [])
        }

        let trustState = trustState(for: cacheState)
        let primary = entries(
            limitId: "codex",
            limit: codex,
            scope: .primary,
            trustState: trustState,
            now: now
        )
        let advanced = report.limits
            .filter { $0.key != "codex" }
            .sorted { $0.key < $1.key }
            .flatMap { key, limit in
                entries(
                    limitId: key,
                    limit: limit,
                    scope: .advanced,
                    trustState: trustState,
                    now: now
                )
            }

        return CodexUsageResetSchedule(
            state: cacheState,
            entries: markNextRecovery(primary) + advanced
        )
    }

    private func entries(
        limitId: String,
        limit: UsageLimitReport,
        scope: CodexUsageResetScheduleEntryScope,
        trustState: CodexUsageResetScheduleTrustState,
        now: Date
    ) -> [CodexUsageResetScheduleEntry] {
        [limit.fiveHour, limit.weekly]
            .compactMap(\.self)
            .map { window in
                makeEntry(
                    limitId: limitId,
                    limitName: limit.limitName,
                    window: window,
                    scope: scope,
                    trustState: trustState,
                    isNextRecovery: false,
                    now: now
                )
            }
            .sorted { lhs, rhs in
                switch (lhs.resetsAt, rhs.resetsAt) {
                case let (.some(left), .some(right)):
                    if left != right {
                        return left < right
                    }
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    break
                }

                let leftPriority = windowKindPriority(lhs.kind)
                let rightPriority = windowKindPriority(rhs.kind)
                if leftPriority != rightPriority {
                    return leftPriority < rightPriority
                }

                return lhs.id < rhs.id
            }
    }

    private func makeEntry(
        limitId: String,
        limitName: String?,
        window: UsageWindowReport,
        scope: CodexUsageResetScheduleEntryScope,
        trustState: CodexUsageResetScheduleTrustState,
        isNextRecovery: Bool,
        now: Date
    ) -> CodexUsageResetScheduleEntry {
        let title = title(for: window)
        let remainingSeconds = window.resetsAt.map {
            max(0, $0 - Int(now.timeIntervalSince1970))
        }
        let id = [
            limitId,
            window.kind.rawValue,
            window.resetsAt.map(String.init) ?? "unknown"
        ].joined(separator: ".")

        return CodexUsageResetScheduleEntry(
            id: id,
            limitId: limitId,
            limitName: limitName,
            title: title,
            kind: window.kind,
            scope: scope,
            windowDurationMins: window.windowDurationMins,
            resetsAt: window.resetsAt,
            remainingSeconds: remainingSeconds,
            usedPercent: window.usedPercent,
            remainingPercent: window.remainingPercent,
            trustState: trustState,
            isNextRecovery: isNextRecovery
        )
    }

    private func markNextRecovery(
        _ entries: [CodexUsageResetScheduleEntry]
    ) -> [CodexUsageResetScheduleEntry] {
        guard let firstID = entries.first(where: { $0.resetsAt != nil })?.id else { return entries }
        return entries.map { entry in
            CodexUsageResetScheduleEntry(
                id: entry.id,
                limitId: entry.limitId,
                limitName: entry.limitName,
                title: entry.title,
                kind: entry.kind,
                scope: entry.scope,
                windowDurationMins: entry.windowDurationMins,
                resetsAt: entry.resetsAt,
                remainingSeconds: entry.remainingSeconds,
                usedPercent: entry.usedPercent,
                remainingPercent: entry.remainingPercent,
                trustState: entry.trustState,
                isNextRecovery: entry.id == firstID
            )
        }
    }

    private func title(for window: UsageWindowReport) -> String {
        switch window.kind {
        case .fiveHour:
            return "5시간"
        case .weekly:
            return "주간"
        case .other:
            return window.windowDurationMins.map { "\($0)분" } ?? "기타"
        }
    }

    private func windowKindPriority(_ kind: UsageWindowKind) -> Int {
        switch kind {
        case .fiveHour:
            return 0
        case .weekly:
            return 1
        case .other:
            return 2
        }
    }

    private func cacheState(
        snapshot: CodexUsageCacheSnapshot?,
        now: Date
    ) -> CodexUsageResetScheduleState {
        guard let snapshot else { return .ok }
        if snapshot.error != nil { return .error }
        if snapshot.isStale(now: now) { return .stale }
        return snapshot.report == nil ? .waiting : .ok
    }

    private func trustState(
        for state: CodexUsageResetScheduleState
    ) -> CodexUsageResetScheduleTrustState {
        switch state {
        case .ok:
            return .fresh
        case .stale:
            return .stale
        case .error:
            return .error
        case .waiting, .protocolDrift:
            return .waiting
        }
    }
}
