import Foundation
import UserNotifications

struct UsageNotificationDeliverySettings: Equatable, Sendable {
    let usageNotificationsEnabled: Bool
    let resetSoonNotificationsEnabled: Bool

    init(
        usageNotificationsEnabled: Bool,
        resetSoonNotificationsEnabled: Bool
    ) {
        self.usageNotificationsEnabled = usageNotificationsEnabled
        self.resetSoonNotificationsEnabled = resetSoonNotificationsEnabled
    }

    init(preferences: RunnerPreferences) {
        self.init(
            usageNotificationsEnabled: preferences.usageNotificationsEnabled,
            resetSoonNotificationsEnabled: preferences.usageResetSoonNotificationsEnabled
        )
    }
}

struct UsageNotificationContent: Equatable, Sendable {
    let identifier: String
    let title: String
    let body: String
}

enum UsageNotificationSkipReason: Equatable, Sendable {
    case notificationsDisabled
    case staleOrUnavailableCache
    case noCandidates
    case notificationsUnauthorized
    case duplicateOnly
    case deliveryFailed
}

struct UsageNotificationDispatchResult: Equatable, Sendable {
    let deliveredKeys: [UsageNotificationDedupeKey]
    let skipReason: UsageNotificationSkipReason?

    static func skipped(_ reason: UsageNotificationSkipReason) -> UsageNotificationDispatchResult {
        UsageNotificationDispatchResult(deliveredKeys: [], skipReason: reason)
    }
}

@MainActor
protocol UsageNotificationDelivering {
    func deliver(_ content: UsageNotificationContent) async throws
}

protocol UsageNotificationDedupeStoring {
    func loadLedger() -> UsageNotificationDedupeLedger
    func saveLedger(_ ledger: UsageNotificationDedupeLedger)
}

struct UserDefaultsUsageNotificationDedupeStore: UsageNotificationDedupeStoring {
    static let deliveredKeysKey = "usageNotificationDeliveredDedupeKeys"

    var defaults: UserDefaults = .standard

    func loadLedger() -> UsageNotificationDedupeLedger {
        guard let data = defaults.data(forKey: Self.deliveredKeysKey),
              let keys = try? JSONDecoder().decode([UsageNotificationDedupeKey].self, from: data) else {
            return UsageNotificationDedupeLedger()
        }

        return UsageNotificationDedupeLedger(deliveredKeys: keys)
    }

    func saveLedger(_ ledger: UsageNotificationDedupeLedger) {
        guard let data = try? JSONEncoder().encode(ledger.deliveredKeys) else { return }
        defaults.set(data, forKey: Self.deliveredKeysKey)
    }
}

struct UsageNotificationCenterDeliveryClient: UsageNotificationDelivering {
    func deliver(_ content: UsageNotificationContent) async throws {
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = content.title
        notificationContent.body = content.body
        notificationContent.sound = .default

        let request = UNNotificationRequest(
            identifier: content.identifier,
            content: notificationContent,
            trigger: nil
        )
        try await UNUserNotificationCenter.current().add(request)
    }
}

@MainActor
final class UsageNotificationDispatcher {
    private let policy: UsageNotificationPolicy
    private let authorizationClient: any UsageNotificationAuthorizationProviding
    private let deliveryClient: any UsageNotificationDelivering
    private let dedupeStore: any UsageNotificationDedupeStoring
    private let now: () -> Date
    private var inFlightKeys: Set<UsageNotificationDedupeKey> = []

    init(
        policy: UsageNotificationPolicy = UsageNotificationPolicy(),
        authorizationClient: any UsageNotificationAuthorizationProviding = UsageNotificationAuthorizationClient(),
        deliveryClient: any UsageNotificationDelivering = UsageNotificationCenterDeliveryClient(),
        dedupeStore: any UsageNotificationDedupeStoring = UserDefaultsUsageNotificationDedupeStore(),
        now: @escaping () -> Date = Date.init
    ) {
        self.policy = policy
        self.authorizationClient = authorizationClient
        self.deliveryClient = deliveryClient
        self.dedupeStore = dedupeStore
        self.now = now
    }

    func dispatch(
        for state: UsageMonitorState,
        settings: UsageNotificationDeliverySettings
    ) async -> UsageNotificationDispatchResult {
        guard settings.usageNotificationsEnabled else {
            return .skipped(.notificationsDisabled)
        }

        let currentDate = now()
        guard let snapshot = state.cacheSnapshot,
              snapshot.report != nil,
              !snapshot.isStale(now: currentDate) else {
            return .skipped(.staleOrUnavailableCache)
        }

        let candidates = filteredCandidates(
            policy.candidates(for: state, now: currentDate),
            settings: settings
        )
        guard !candidates.isEmpty else {
            return .skipped(.noCandidates)
        }

        let authorizationStatus = await authorizationClient.authorizationStatus()
        guard authorizationStatus.allowsDelivery else {
            return .skipped(.notificationsUnauthorized)
        }

        let ledger = dedupeStore.loadLedger()
        let newKeys = ledger.newKeys(candidates.map(\.dedupeKey))
            .filter { !inFlightKeys.contains($0) }
        let deliverableCandidates = candidates.filter { newKeys.contains($0.dedupeKey) }
        guard !deliverableCandidates.isEmpty else {
            return .skipped(.duplicateOnly)
        }

        for key in newKeys {
            inFlightKeys.insert(key)
        }
        defer {
            for key in newKeys {
                inFlightKeys.remove(key)
            }
        }

        var deliveredKeys: [UsageNotificationDedupeKey] = []
        for candidate in deliverableCandidates {
            do {
                try await deliveryClient.deliver(candidate.notificationContent)
                deliveredKeys.append(candidate.dedupeKey)
            } catch {
                continue
            }
        }

        guard !deliveredKeys.isEmpty else {
            return .skipped(.deliveryFailed)
        }

        dedupeStore.saveLedger(ledger.recording(deliveredKeys))
        return UsageNotificationDispatchResult(deliveredKeys: deliveredKeys, skipReason: nil)
    }

    private func filteredCandidates(
        _ candidates: [UsageNotificationCandidate],
        settings: UsageNotificationDeliverySettings
    ) -> [UsageNotificationCandidate] {
        if settings.resetSoonNotificationsEnabled {
            return candidates
        }

        return candidates.filter { $0.event != .resetSoon }
    }
}

private extension UsageNotificationCandidate {
    var notificationContent: UsageNotificationContent {
        UsageNotificationContent(
            identifier: dedupeKey.rawValue,
            title: title,
            body: body
        )
    }

    var title: String {
        switch event {
        case .highUsage:
            "Codex 사용량 높음"
        case .approachingLimit:
            "Codex 한도 임박"
        case .limitReached:
            "Codex 한도 도달"
        case .resetSoon:
            "Codex reset 임박"
        }
    }

    var body: String {
        let percent = UsageMonitorState.percent(usedPercent)
        switch event {
        case .highUsage:
            return "\(window.label) 사용량이 \(percent)%입니다."
        case .approachingLimit:
            return "\(window.label) 사용량이 \(percent)%입니다. 한도에 가까워지고 있습니다."
        case .limitReached:
            return "\(window.label) 사용량이 \(percent)%입니다. 한도 도달 상태를 확인하세요."
        case .resetSoon:
            return "\(window.label) 사용량이 \(percent)%이고 reset까지 30분 이하입니다."
        }
    }
}
