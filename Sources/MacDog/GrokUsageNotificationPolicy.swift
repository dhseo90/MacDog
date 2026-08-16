import CodexUsageCore
import Foundation

struct GrokUsageNotificationPolicy: Equatable {
    func candidates(
        for preview: GrokUsagePreviewState,
        now: Date = Date()
    ) -> [GrokUsageNotificationCandidate] {
        guard preview.status(now: now) == .available,
              let weekly = preview.cacheSnapshot?.freshWeekly(now: now),
              let resetsAt = weekly.resetsAt else {
            return []
        }
        let usedPercent = weekly.usedPercent
        var candidates: [GrokUsageNotificationCandidate] = []
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
            candidates.append(GrokUsageNotificationCandidate(
                event: event,
                usedPercent: usedPercent,
                resetsAt: resetsAt
            ))
        }
        if usedPercent >= UsageNotificationPolicy.highUsageThresholdPercent {
            let remaining = Date(timeIntervalSince1970: TimeInterval(resetsAt)).timeIntervalSince(now)
            if remaining > 0, remaining <= UsageNotificationPolicy.resetSoonLeadTime {
                candidates.append(GrokUsageNotificationCandidate(
                    event: .resetSoon,
                    usedPercent: usedPercent,
                    resetsAt: resetsAt
                ))
            }
        }
        return candidates
    }
}

struct GrokUsageNotificationCandidate: Equatable, Sendable {
    let event: UsageNotificationEvent
    let usedPercent: Double
    let resetsAt: Int

    var dedupeKey: GrokUsageNotificationDedupeKey {
        GrokUsageNotificationDedupeKey(event: event, resetsAt: resetsAt)
    }

    var content: UsageNotificationContent {
        UsageNotificationContent(
            identifier: dedupeKey.rawValue,
            title: title,
            body: body
        )
    }

    private var title: String {
        switch event {
        case .highUsage: "Grok 사용량 높음"
        case .approachingLimit: "Grok 한도 임박"
        case .limitReached: "Grok 한도 도달"
        case .resetSoon: "Grok 회복 임박"
        case .dailyTargetApproaching, .dailyTargetExceeded, .cumulativePaceExceeded:
            "Grok 사용량"
        }
    }

    private var body: String {
        let percent = UsageMonitorState.percent(usedPercent)
        switch event {
        case .highUsage:
            return "주간 사용량이 \(percent)%입니다."
        case .approachingLimit:
            return "주간 사용량이 \(percent)%입니다. 한도에 가까워지고 있습니다."
        case .limitReached:
            return "주간 사용량이 \(percent)%입니다. 한도 도달 상태를 확인하세요."
        case .resetSoon:
            return "주간 한도가 곧 회복됩니다."
        case .dailyTargetApproaching, .dailyTargetExceeded, .cumulativePaceExceeded:
            return "주간 사용량 상태를 확인하세요."
        }
    }
}

struct GrokUsageNotificationDedupeKey: Codable, Hashable, Sendable {
    let event: UsageNotificationEvent
    let resetsAt: Int

    var rawValue: String {
        "grok.usage.\(event.rawValue).weekly.reset.\(resetsAt)"
    }
}

private struct GrokUsageNotificationLedger: Codable, Equatable {
    var deliveredKeys: [GrokUsageNotificationDedupeKey]
}

@MainActor
final class GrokUsageNotificationDispatcher {
    private static let ledgerKey = "grokUsageNotificationDeliveredDedupeKeys"

    private let policy: GrokUsageNotificationPolicy
    private let authorizationClient: any UsageNotificationAuthorizationProviding
    private let deliveryClient: any UsageNotificationDelivering
    private let defaults: UserDefaults
    private let now: () -> Date
    private var inFlightKeys: Set<GrokUsageNotificationDedupeKey> = []

    init(
        policy: GrokUsageNotificationPolicy = GrokUsageNotificationPolicy(),
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
        for preview: GrokUsagePreviewState,
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
        guard !Task.isCancelled else { return 0 }

        let ledger = loadLedger()
        let existing = Set(ledger.deliveredKeys)
        let deliverable = candidates.filter {
            !existing.contains($0.dedupeKey) && !inFlightKeys.contains($0.dedupeKey)
        }
        guard !deliverable.isEmpty else { return 0 }
        deliverable.forEach { inFlightKeys.insert($0.dedupeKey) }
        defer { deliverable.forEach { inFlightKeys.remove($0.dedupeKey) } }

        var delivered: [GrokUsageNotificationDedupeKey] = []
        for candidate in deliverable {
            if Task.isCancelled {
                if !delivered.isEmpty {
                    saveLedger(GrokUsageNotificationLedger(
                        deliveredKeys: Array(Set(ledger.deliveredKeys + delivered))
                    ))
                }
                return delivered.count
            }
            do {
                try await deliveryClient.deliver(candidate.content)
                delivered.append(candidate.dedupeKey)
            } catch {
                continue
            }
        }
        if !delivered.isEmpty {
            saveLedger(GrokUsageNotificationLedger(
                deliveredKeys: Array(Set(ledger.deliveredKeys + delivered))
            ))
        }
        return delivered.count
    }

    private func loadLedger() -> GrokUsageNotificationLedger {
        guard let data = defaults.data(forKey: Self.ledgerKey),
              let ledger = try? JSONDecoder().decode(GrokUsageNotificationLedger.self, from: data)
        else { return GrokUsageNotificationLedger(deliveredKeys: []) }
        return ledger
    }

    private func saveLedger(_ ledger: GrokUsageNotificationLedger) {
        guard let data = try? JSONEncoder().encode(ledger) else { return }
        defaults.set(data, forKey: Self.ledgerKey)
    }
}
