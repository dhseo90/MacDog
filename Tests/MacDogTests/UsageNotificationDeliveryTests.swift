import XCTest
import CodexUsageCore
@testable import MacDog

@MainActor
final class UsageNotificationDeliveryTests: XCTestCase {
    func testDispatcherDeliversAuthorizedFreshCacheCandidatesAndPersistsDedupe() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let deliveryClient = RecordingUsageNotificationDeliveryClient()
        let dedupeStore = InMemoryUsageNotificationDedupeStore()
        let dispatcher = UsageNotificationDispatcher(
            authorizationClient: StaticUsageNotificationAuthorizationClient(status: .authorized),
            deliveryClient: deliveryClient,
            dedupeStore: dedupeStore,
            now: { now }
        )
        let state = Self.cachedState(
            fiveHourUsedPercent: 82,
            fiveHourResetsAt: 1_800_001_800,
            weeklyUsedPercent: 42,
            weeklyResetsAt: 1_800_604_800,
            cachedAt: 1_800_000_000
        )

        let result = await dispatcher.dispatch(
            for: state,
            settings: UsageNotificationDeliverySettings(
                usageNotificationsEnabled: true,
                resetSoonNotificationsEnabled: true
            )
        )

        XCTAssertEqual(result.deliveredKeys.map(\.rawValue), [
            "usage.highUsage.fiveHour.reset.1800001800",
            "usage.resetSoon.fiveHour.reset.1800001800"
        ])
        let deliveredContents = deliveryClient.deliveredContents()
        XCTAssertEqual(deliveredContents.map(\.identifier), [
            "usage.highUsage.fiveHour.reset.1800001800",
            "usage.resetSoon.fiveHour.reset.1800001800"
        ])
        XCTAssertEqual(deliveredContents.map(\.title), [
            "Codex 사용량 높음",
            "Codex reset 임박"
        ])
        XCTAssertEqual(dedupeStore.ledger.deliveredKeys.map(\.rawValue), result.deliveredKeys.map(\.rawValue))
    }

    func testDispatcherFiltersResetSoonAndAlreadyDeliveredKeys() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let deliveryClient = RecordingUsageNotificationDeliveryClient()
        let dedupeStore = InMemoryUsageNotificationDedupeStore(
            ledger: UsageNotificationDedupeLedger(deliveredKeys: [
                UsageNotificationDedupeKey(
                    event: .highUsage,
                    window: .fiveHour,
                    resetsAt: 1_800_001_800
                )
            ])
        )
        let dispatcher = UsageNotificationDispatcher(
            authorizationClient: StaticUsageNotificationAuthorizationClient(status: .authorized),
            deliveryClient: deliveryClient,
            dedupeStore: dedupeStore,
            now: { now }
        )
        let state = Self.cachedState(
            fiveHourUsedPercent: 82,
            fiveHourResetsAt: 1_800_001_800,
            weeklyUsedPercent: 42,
            weeklyResetsAt: 1_800_604_800,
            cachedAt: 1_800_000_000
        )

        let result = await dispatcher.dispatch(
            for: state,
            settings: UsageNotificationDeliverySettings(
                usageNotificationsEnabled: true,
                resetSoonNotificationsEnabled: false
            )
        )

        XCTAssertEqual(result.deliveredKeys, [])
        let deliveredContents = deliveryClient.deliveredContents()
        XCTAssertEqual(deliveredContents, [])
        XCTAssertEqual(dedupeStore.ledger.deliveredKeys.map(\.rawValue), [
            "usage.highUsage.fiveHour.reset.1800001800"
        ])
    }

    func testDispatcherDoesNotDuplicateInFlightWindowEventDuringConcurrentRefreshes() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let deliveryClient = SlowRecordingUsageNotificationDeliveryClient()
        let dispatcher = UsageNotificationDispatcher(
            authorizationClient: StaticUsageNotificationAuthorizationClient(status: .authorized),
            deliveryClient: deliveryClient,
            dedupeStore: InMemoryUsageNotificationDedupeStore(),
            now: { now }
        )
        let state = Self.cachedState(
            fiveHourUsedPercent: 82,
            fiveHourResetsAt: 1_800_003_600,
            weeklyUsedPercent: 42,
            weeklyResetsAt: 1_800_604_800,
            cachedAt: 1_800_000_000
        )
        let settings = UsageNotificationDeliverySettings(
            usageNotificationsEnabled: true,
            resetSoonNotificationsEnabled: true
        )

        let first = Task { @MainActor in
            await dispatcher.dispatch(for: state, settings: settings)
        }
        let second = Task { @MainActor in
            await dispatcher.dispatch(for: state, settings: settings)
        }
        _ = await [first.value, second.value]

        XCTAssertEqual(deliveryClient.deliveredContents().map(\.identifier), [
            "usage.highUsage.fiveHour.reset.1800003600"
        ])
    }

    func testDispatcherSkipsStaleCache() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_180)
        let deliveryClient = RecordingUsageNotificationDeliveryClient()
        let dispatcher = UsageNotificationDispatcher(
            authorizationClient: StaticUsageNotificationAuthorizationClient(status: .authorized),
            deliveryClient: deliveryClient,
            dedupeStore: InMemoryUsageNotificationDedupeStore(),
            now: { now }
        )
        let state = Self.cachedState(
            fiveHourUsedPercent: 96,
            fiveHourResetsAt: 1_800_003_600,
            weeklyUsedPercent: 42,
            weeklyResetsAt: 1_800_604_800,
            cachedAt: 1_800_000_000,
            staleAfterSeconds: 60
        )

        let result = await dispatcher.dispatch(
            for: state,
            settings: UsageNotificationDeliverySettings(
                usageNotificationsEnabled: true,
                resetSoonNotificationsEnabled: true
            )
        )

        XCTAssertEqual(result.deliveredKeys, [])
        XCTAssertEqual(result.skipReason, .staleOrUnavailableCache)
        let deliveredContents = deliveryClient.deliveredContents()
        XCTAssertEqual(deliveredContents, [])
    }

    func testDispatcherSkipsDisabledNotificationsBeforeAuthorizationOrDelivery() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let deliveryClient = RecordingUsageNotificationDeliveryClient()
        let dispatcher = UsageNotificationDispatcher(
            authorizationClient: StaticUsageNotificationAuthorizationClient(status: .authorized),
            deliveryClient: deliveryClient,
            dedupeStore: InMemoryUsageNotificationDedupeStore(),
            now: { now }
        )
        let state = Self.cachedState(
            fiveHourUsedPercent: 96,
            fiveHourResetsAt: 1_800_003_600,
            weeklyUsedPercent: 42,
            weeklyResetsAt: 1_800_604_800,
            cachedAt: 1_800_000_000
        )

        let result = await dispatcher.dispatch(
            for: state,
            settings: UsageNotificationDeliverySettings(
                usageNotificationsEnabled: false,
                resetSoonNotificationsEnabled: true
            )
        )

        XCTAssertEqual(result.deliveredKeys, [])
        XCTAssertEqual(result.skipReason, .notificationsDisabled)
        XCTAssertEqual(deliveryClient.deliveredContents(), [])
    }

    func testDispatcherSkipsCacheSnapshotsWithErrorState() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let deliveryClient = RecordingUsageNotificationDeliveryClient()
        let dispatcher = UsageNotificationDispatcher(
            authorizationClient: StaticUsageNotificationAuthorizationClient(status: .authorized),
            deliveryClient: deliveryClient,
            dedupeStore: InMemoryUsageNotificationDedupeStore(),
            now: { now }
        )
        let state = Self.cachedState(
            fiveHourUsedPercent: 96,
            fiveHourResetsAt: 1_800_003_600,
            weeklyUsedPercent: 42,
            weeklyResetsAt: 1_800_604_800,
            cachedAt: 1_800_000_000,
            errorMessage: "network unavailable"
        )

        let result = await dispatcher.dispatch(
            for: state,
            settings: UsageNotificationDeliverySettings(
                usageNotificationsEnabled: true,
                resetSoonNotificationsEnabled: true
            )
        )

        XCTAssertEqual(result.deliveredKeys, [])
        XCTAssertEqual(result.skipReason, .staleOrUnavailableCache)
        XCTAssertEqual(deliveryClient.deliveredContents(), [])
    }

    func testDispatcherDoesNotRecordDedupeWhenDeliveryFails() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let dedupeStore = InMemoryUsageNotificationDedupeStore()
        let dispatcher = UsageNotificationDispatcher(
            authorizationClient: StaticUsageNotificationAuthorizationClient(status: .authorized),
            deliveryClient: FailingUsageNotificationDeliveryClient(),
            dedupeStore: dedupeStore,
            now: { now }
        )
        let state = Self.cachedState(
            fiveHourUsedPercent: 96,
            fiveHourResetsAt: 1_800_003_600,
            weeklyUsedPercent: 42,
            weeklyResetsAt: 1_800_604_800,
            cachedAt: 1_800_000_000
        )

        let result = await dispatcher.dispatch(
            for: state,
            settings: UsageNotificationDeliverySettings(
                usageNotificationsEnabled: true,
                resetSoonNotificationsEnabled: true
            )
        )

        XCTAssertEqual(result.deliveredKeys, [])
        XCTAssertEqual(result.skipReason, .deliveryFailed)
        XCTAssertEqual(dedupeStore.ledger.deliveredKeys, [])
    }

    func testDispatcherSkipsDeniedPermissionWithoutRecordingDedupe() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let deliveryClient = RecordingUsageNotificationDeliveryClient()
        let dedupeStore = InMemoryUsageNotificationDedupeStore()
        let dispatcher = UsageNotificationDispatcher(
            authorizationClient: StaticUsageNotificationAuthorizationClient(status: .denied),
            deliveryClient: deliveryClient,
            dedupeStore: dedupeStore,
            now: { now }
        )
        let state = Self.cachedState(
            fiveHourUsedPercent: 96,
            fiveHourResetsAt: 1_800_003_600,
            weeklyUsedPercent: 42,
            weeklyResetsAt: 1_800_604_800,
            cachedAt: 1_800_000_000
        )

        let result = await dispatcher.dispatch(
            for: state,
            settings: UsageNotificationDeliverySettings(
                usageNotificationsEnabled: true,
                resetSoonNotificationsEnabled: true
            )
        )

        XCTAssertEqual(result.deliveredKeys, [])
        XCTAssertEqual(result.skipReason, .notificationsUnauthorized)
        let deliveredContents = deliveryClient.deliveredContents()
        XCTAssertEqual(deliveredContents, [])
        XCTAssertEqual(dedupeStore.ledger.deliveredKeys, [])
    }

    func testUserDefaultsDedupeStorePersistsDeliveredKeysOutsideUsageCache() throws {
        let suiteName = "UsageNotificationDeliveryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let key = UsageNotificationDedupeKey(
            event: .approachingLimit,
            window: .weekly,
            resetsAt: 1_800_604_800
        )

        UserDefaultsUsageNotificationDedupeStore(defaults: defaults)
            .saveLedger(UsageNotificationDedupeLedger(deliveredKeys: [key]))
        let reloaded = UserDefaultsUsageNotificationDedupeStore(defaults: defaults).loadLedger()

        XCTAssertEqual(reloaded.deliveredKeys, [key])
        XCTAssertNotNil(defaults.data(forKey: UserDefaultsUsageNotificationDedupeStore.deliveredKeysKey))
        XCTAssertNil(defaults.object(forKey: "cachedAt"))
        XCTAssertNil(defaults.object(forKey: "report"))
        XCTAssertNil(defaults.object(forKey: "schemaVersion"))
    }

    private static func cachedState(
        fiveHourUsedPercent: Double,
        fiveHourResetsAt: Int?,
        weeklyUsedPercent: Double,
        weeklyResetsAt: Int?,
        cachedAt: Int,
        staleAfterSeconds: Int = 120,
        errorMessage: String? = nil
    ) -> UsageMonitorState {
        let report = report(
            fiveHourUsedPercent: fiveHourUsedPercent,
            fiveHourResetsAt: fiveHourResetsAt,
            weeklyUsedPercent: weeklyUsedPercent,
            weeklyResetsAt: weeklyResetsAt
        )
        let snapshot = CodexUsageCacheSnapshot(
            cachedAt: cachedAt,
            staleAfterSeconds: staleAfterSeconds,
            report: report,
            error: errorMessage.map {
                CodexUsageCacheError(message: $0, recordedAt: cachedAt)
            }
        )
        return UsageMonitorState(report: report, cacheSnapshot: snapshot, errorMessage: nil)
    }

    private static func report(
        fiveHourUsedPercent: Double,
        fiveHourResetsAt: Int?,
        weeklyUsedPercent: Double,
        weeklyResetsAt: Int?
    ) -> CodexUsageReport {
        let fiveHour = UsageWindowReport(
            kind: .fiveHour,
            usedPercent: fiveHourUsedPercent,
            remainingPercent: 100 - fiveHourUsedPercent,
            windowDurationMins: 300,
            resetsAt: fiveHourResetsAt
        )
        let weekly = UsageWindowReport(
            kind: .weekly,
            usedPercent: weeklyUsedPercent,
            remainingPercent: 100 - weeklyUsedPercent,
            windowDurationMins: 10_080,
            resetsAt: weeklyResetsAt
        )
        let limit = UsageLimitReport(
            limitId: "codex",
            limitName: "Codex",
            primary: fiveHour,
            secondary: weekly,
            credits: nil,
            planType: "pro",
            rateLimitReachedType: nil
        )
        return CodexUsageReport(
            generatedAt: 0,
            source: "test",
            planType: "pro",
            credits: nil,
            rateLimitReachedType: nil,
            limits: ["codex": limit]
        )
    }
}

@MainActor
private final class RecordingUsageNotificationDeliveryClient: UsageNotificationDelivering {
    private var contents: [UsageNotificationContent] = []

    func deliver(_ content: UsageNotificationContent) async throws {
        contents.append(content)
    }

    func deliveredContents() -> [UsageNotificationContent] {
        contents
    }
}

private final class InMemoryUsageNotificationDedupeStore: UsageNotificationDedupeStoring {
    private(set) var ledger: UsageNotificationDedupeLedger

    init(ledger: UsageNotificationDedupeLedger = UsageNotificationDedupeLedger()) {
        self.ledger = ledger
    }

    func loadLedger() -> UsageNotificationDedupeLedger {
        ledger
    }

    func saveLedger(_ ledger: UsageNotificationDedupeLedger) {
        self.ledger = ledger
    }
}

private struct FailingUsageNotificationDeliveryClient: UsageNotificationDelivering {
    func deliver(_ content: UsageNotificationContent) async throws {
        throw NSError(domain: "UsageNotificationDeliveryTests", code: 1)
    }
}

@MainActor
private final class SlowRecordingUsageNotificationDeliveryClient: UsageNotificationDelivering {
    private var contents: [UsageNotificationContent] = []

    func deliver(_ content: UsageNotificationContent) async throws {
        contents.append(content)
        try? await Task.sleep(nanoseconds: 30_000_000)
    }

    func deliveredContents() -> [UsageNotificationContent] {
        contents
    }
}
