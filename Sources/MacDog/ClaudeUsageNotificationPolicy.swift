import CodexUsageCore
import Foundation

struct ClaudeUsageNotificationPolicy: Equatable {
    func candidates(
        for preview: ClaudeUsagePreviewState,
        now: Date = Date()
    ) -> [ClaudeUsageNotificationCandidate] {
        guard preview.status(now: now) == .available || preview.status(now: now) == .partial,
              let usage = preview.usage else { return [] }
        return ClaudeUsageWindowKind.allCases.flatMap { kind -> [ClaudeUsageNotificationCandidate] in
            guard let window = usage.window(kind), let usedPercent = window.usedPercent else { return [] }
            var candidates: [ClaudeUsageNotificationCandidate] = []
            let event: UsageNotificationEvent?
            switch usedPercent {
            case UsageNotificationPolicy.limitReachedThresholdPercent...:
                event = .limitReached
            case UsageNotificationPolicy.approachingLimitThresholdPercent..<UsageNotificationPolicy.limitReachedThresholdPercent:
                event = .approachingLimit
            case UsageNotificationPolicy.highUsageThresholdPercent..<UsageNotificationPolicy.approachingLimitThresholdPercent:
                event = .highUsage
            default:
                event = nil
            }
            if let event {
                candidates.append(ClaudeUsageNotificationCandidate(
                    event: event,
                    window: kind,
                    usedPercent: usedPercent,
                    resetsAt: window.resetsAt
                ))
            }
            if usedPercent >= UsageNotificationPolicy.highUsageThresholdPercent,
               let resetsAt = window.resetsAt {
                let remaining = Date(timeIntervalSince1970: TimeInterval(resetsAt)).timeIntervalSince(now)
                if remaining > 0, remaining <= UsageNotificationPolicy.resetSoonLeadTime {
                    candidates.append(ClaudeUsageNotificationCandidate(
                        event: .resetSoon,
                        window: kind,
                        usedPercent: usedPercent,
                        resetsAt: resetsAt
                    ))
                }
            }
            return candidates
        }
    }
}

struct ClaudeUsageNotificationCandidate: Equatable, Sendable {
    let event: UsageNotificationEvent
    let window: ClaudeUsageWindowKind
    let usedPercent: Double
    let resetsAt: Int?

    var dedupeKey: ClaudeUsageNotificationDedupeKey {
        ClaudeUsageNotificationDedupeKey(event: event, window: window, resetsAt: resetsAt)
    }

    var content: UsageNotificationContent {
        UsageNotificationContent(
            identifier: dedupeKey.rawValue,
            title: title,
            body: body
        )
    }

    private var title: String {
        return switch event {
        case .highUsage: "Claude 사용량 높음"
        case .approachingLimit: "Claude 한도 임박"
        case .limitReached: "Claude 한도 도달"
        case .resetSoon: "Claude 회복 임박"
        }
    }

    private var body: String {
        let label = window == .fiveHour ? "5시간" : "7일"
        let percent = UsageMonitorState.percent(usedPercent)
        return switch event {
        case .highUsage:
            "\(label) 사용량이 \(percent)%입니다."
        case .approachingLimit:
            "\(label) 사용량이 \(percent)%입니다. 한도에 가까워지고 있습니다."
        case .limitReached:
            "\(label) 사용량이 \(percent)%입니다. 한도 도달 상태를 확인하세요."
        case .resetSoon:
            "\(label) 한도가 곧 회복됩니다."
        }
    }
}

struct ClaudeUsageNotificationDedupeKey: Codable, Hashable, Sendable {
    let event: UsageNotificationEvent
    let window: ClaudeUsageWindowKind
    let resetsAt: Int?

    var rawValue: String {
        "claude.usage.\(event.rawValue).\(window.rawValue).reset.\(resetsAt.map(String.init) ?? "unknown")"
    }
}

private struct ClaudeUsageNotificationLedger: Codable, Equatable {
    var deliveredKeys: [ClaudeUsageNotificationDedupeKey]
}

@MainActor
final class ClaudeUsageNotificationDispatcher {
    private static let ledgerKey = "claudeUsageNotificationDeliveredDedupeKeys"

    private let policy: ClaudeUsageNotificationPolicy
    private let authorizationClient: any UsageNotificationAuthorizationProviding
    private let deliveryClient: any UsageNotificationDelivering
    private let defaults: UserDefaults
    private let now: () -> Date
    private var inFlightKeys: Set<ClaudeUsageNotificationDedupeKey> = []

    init(
        policy: ClaudeUsageNotificationPolicy = ClaudeUsageNotificationPolicy(),
        authorizationClient: any UsageNotificationAuthorizationProviding = UsageNotificationAuthorizationClient(),
        deliveryClient: any UsageNotificationDelivering = UsageNotificationCenterDeliveryClient(),
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init
    ) {
        self.policy = policy
        self.authorizationClient = authorizationClient
        self.deliveryClient = deliveryClient
        self.defaults = defaults
        self.now = now
    }

    func dispatch(
        for preview: ClaudeUsagePreviewState,
        enabled: Bool,
        resetSoonEnabled: Bool
    ) async -> Int {
        guard enabled else { return 0 }
        let currentDate = now()
        var candidates = policy.candidates(for: preview, now: currentDate)
        if !resetSoonEnabled {
            candidates.removeAll { $0.event == .resetSoon }
        }
        guard !candidates.isEmpty,
              (await authorizationClient.authorizationStatus()).allowsDelivery else { return 0 }

        let ledger = loadLedger()
        let existing = Set(ledger.deliveredKeys)
        let deliverable = candidates.filter {
            !existing.contains($0.dedupeKey) && !inFlightKeys.contains($0.dedupeKey)
        }
        guard !deliverable.isEmpty else { return 0 }
        deliverable.forEach { inFlightKeys.insert($0.dedupeKey) }
        defer { deliverable.forEach { inFlightKeys.remove($0.dedupeKey) } }

        var delivered: [ClaudeUsageNotificationDedupeKey] = []
        for candidate in deliverable {
            do {
                try await deliveryClient.deliver(candidate.content)
                delivered.append(candidate.dedupeKey)
            } catch {
                continue
            }
        }
        if !delivered.isEmpty {
            saveLedger(ClaudeUsageNotificationLedger(
                deliveredKeys: Array(Set(ledger.deliveredKeys + delivered))
            ))
        }
        return delivered.count
    }

    private func loadLedger() -> ClaudeUsageNotificationLedger {
        guard let data = defaults.data(forKey: Self.ledgerKey),
              let ledger = try? JSONDecoder().decode(ClaudeUsageNotificationLedger.self, from: data)
        else { return ClaudeUsageNotificationLedger(deliveredKeys: []) }
        return ledger
    }

    private func saveLedger(_ ledger: ClaudeUsageNotificationLedger) {
        guard let data = try? JSONEncoder().encode(ledger) else { return }
        defaults.set(data, forKey: Self.ledgerKey)
    }
}
