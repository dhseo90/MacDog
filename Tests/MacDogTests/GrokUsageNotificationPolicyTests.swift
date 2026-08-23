import CodexUsageCore
import XCTest
@testable import MacDog

final class GrokUsageNotificationPolicyTests: XCTestCase {
    func testCreatesWeeklyOnlyCandidatesForFreshPreview() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let preview = try makePreview(usedPercent: 96, resetsAt: 1_900_000_600)

        let candidates = GrokUsageNotificationPolicy().candidates(for: preview, now: now)

        XCTAssertTrue(candidates.contains { $0.event == .approachingLimit })
        XCTAssertTrue(candidates.contains { $0.event == .resetSoon })
        XCTAssertTrue(candidates.allSatisfy { $0.dedupeKey.rawValue.hasPrefix("grok.usage.") })
        XCTAssertTrue(candidates.allSatisfy { $0.dedupeKey.rawValue.contains("weekly") })
    }

    func testStaleDisabledAndMissingResetDoNotCreateCandidates() throws {
        let now = Date(timeIntervalSince1970: 1_900_010_000)
        let stale = try makePreview(usedPercent: 99, resetsAt: 1_900_020_000, staleAfterSeconds: 60)
        let noReset = try makePreview(usedPercent: 99, resetsAt: nil)

        XCTAssertTrue(GrokUsageNotificationPolicy().candidates(for: stale, now: now).isEmpty)
        XCTAssertTrue(GrokUsageNotificationPolicy().candidates(for: .disabled, now: now).isEmpty)
        XCTAssertTrue(GrokUsageNotificationPolicy().candidates(for: noReset, now: now).isEmpty)
    }

    func testHighUsageDoesNotUseCodexPercent() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let preview = try makePreview(usedPercent: 20, resetsAt: 1_900_100_000)
        let candidates = GrokUsageNotificationPolicy().candidates(for: preview, now: now)
        XCTAssertTrue(candidates.isEmpty)
    }

    @MainActor
    func testDispatcherUsesSeparateLedgerAndDeduplicatesGrokCandidates() async throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let suite = "GrokUsageNotificationPolicyTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let delivery = RecordingGrokDelivery()
        let dispatcher = GrokUsageNotificationDispatcher(
            authorizationClient: StaticUsageNotificationAuthorizationClient(status: .authorized),
            deliveryClient: delivery,
            defaults: defaults,
            now: { now }
        )
        let preview = try makePreview(usedPercent: 96, resetsAt: 1_900_000_600)

        let first = await dispatcher.dispatch(for: preview, enabled: true, resetSoonEnabled: true)
        let second = await dispatcher.dispatch(for: preview, enabled: true, resetSoonEnabled: true)

        XCTAssertEqual(first, 2)
        XCTAssertEqual(second, 0)
        XCTAssertTrue(delivery.titles.allSatisfy { $0.contains("Grok") })
        XCTAssertFalse(delivery.titles.contains { $0.contains("Codex") || $0.contains("Claude") })
    }

    private func makePreview(
        usedPercent: Double,
        resetsAt: Int?,
        staleAfterSeconds: Int = 900
    ) throws -> GrokUsagePreviewState {
        let weekly = try XCTUnwrap(GrokUsageWeeklyWindow(usedPercent: usedPercent, resetsAt: resetsAt))
        return GrokUsagePreviewState(
            isEnabled: true,
            cacheSnapshot: GrokUsageCacheSnapshot(
                fetchedAt: 1_900_000_000,
                lastUsageObservedAt: 1_900_000_000,
                staleAfterSeconds: staleAfterSeconds,
                weekly: weekly,
                issue: nil
            ),
            history: .empty,
            loadIssue: nil
        )
    }
}

private final class RecordingGrokDelivery: UsageNotificationDelivering {
    private(set) var titles: [String] = []

    func deliver(_ content: UsageNotificationContent) async throws {
        titles.append(content.title)
    }
}
