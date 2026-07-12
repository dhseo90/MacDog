import CodexUsageCore
import XCTest
@testable import MacDog

final class ClaudeUsageNotificationPolicyTests: XCTestCase {
    func testCreatesProviderSeparatedCandidatesForFreshPreview() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let preview = makePreview(
            fiveHourUsed: 96,
            sevenDayUsed: 85,
            resetsAt: 1_900_000_600
        )

        let candidates = ClaudeUsageNotificationPolicy().candidates(for: preview, now: now)

        XCTAssertTrue(candidates.contains { $0.window == .fiveHour && $0.event == .approachingLimit })
        XCTAssertTrue(candidates.contains { $0.window == .sevenDay && $0.event == .highUsage })
        XCTAssertTrue(candidates.contains { $0.event == .resetSoon })
        XCTAssertTrue(candidates.allSatisfy { $0.dedupeKey.rawValue.hasPrefix("claude.usage.") })
    }

    func testStaleAndDisabledPreviewDoNotCreateCandidates() throws {
        let now = Date(timeIntervalSince1970: 1_900_010_000)
        let stale = makePreview(
            fiveHourUsed: 99,
            sevenDayUsed: 99,
            resetsAt: 1_900_020_000,
            staleAfterSeconds: 60
        )

        XCTAssertTrue(ClaudeUsageNotificationPolicy().candidates(for: stale, now: now).isEmpty)
        XCTAssertTrue(ClaudeUsageNotificationPolicy().candidates(for: .disabled, now: now).isEmpty)
    }

    func testExpiredWindowAndMissingResetDoNotCreateCandidatesWhenOtherWindowIsFresh() throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let observedAt = 1_899_999_900
        let usage = ClaudeStatusLineSnapshot(
            observedAt: observedAt,
            model: nil,
            fiveHour: try ClaudeUsageWindowSnapshot(usedPercent: 99, resetsAt: 1_899_999_999),
            sevenDay: try ClaudeUsageWindowSnapshot(usedPercent: 20, resetsAt: 1_900_100_000)
        )
        let preview = ClaudeUsagePreviewState(
            isEnabled: true,
            cacheSnapshot: ClaudeUsageCacheSnapshot(
                lastEventAt: observedAt,
                lastUsageObservedAt: observedAt,
                staleAfterSeconds: 900,
                usage: usage,
                issue: nil
            ),
            history: .empty,
            loadIssue: nil
        )
        let noResetUsage = ClaudeStatusLineSnapshot(
            observedAt: observedAt,
            model: nil,
            fiveHour: try ClaudeUsageWindowSnapshot(usedPercent: 99, resetsAt: nil),
            sevenDay: nil
        )
        let noResetPreview = ClaudeUsagePreviewState(
            isEnabled: true,
            cacheSnapshot: ClaudeUsageCacheSnapshot(
                lastEventAt: observedAt,
                lastUsageObservedAt: observedAt,
                staleAfterSeconds: 900,
                usage: noResetUsage,
                issue: nil
            ),
            history: .empty,
            loadIssue: nil
        )

        XCTAssertEqual(preview.status(now: now), .partial)
        XCTAssertTrue(ClaudeUsageNotificationPolicy().candidates(for: preview, now: now).isEmpty)
        XCTAssertTrue(ClaudeUsageNotificationPolicy().candidates(for: noResetPreview, now: now).isEmpty)
    }

    @MainActor
    func testDispatcherUsesSeparateLedgerAndDeduplicatesClaudeCandidates() async throws {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let suite = "ClaudeUsageNotificationPolicyTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let delivery = RecordingDelivery()
        let dispatcher = ClaudeUsageNotificationDispatcher(
            authorizationClient: StaticUsageNotificationAuthorizationClient(status: .authorized),
            deliveryClient: delivery,
            defaults: defaults,
            now: { now }
        )
        let preview = makePreview(
            fiveHourUsed: 96,
            sevenDayUsed: 20,
            resetsAt: 1_900_010_000
        )

        let first = await dispatcher.dispatch(
            for: preview,
            enabled: true,
            resetSoonEnabled: true
        )
        let second = await dispatcher.dispatch(
            for: preview,
            enabled: true,
            resetSoonEnabled: true
        )
        let deliveredCount = delivery.deliveredCount()
        let identifiers = delivery.identifiers()

        XCTAssertEqual(first, 1)
        XCTAssertEqual(second, 0)
        XCTAssertEqual(deliveredCount, 1)
        XCTAssertTrue(identifiers.allSatisfy { $0.hasPrefix("claude.usage.") })
    }

    private func makePreview(
        fiveHourUsed: Double,
        sevenDayUsed: Double,
        resetsAt: Int,
        staleAfterSeconds: Int = 900
    ) -> ClaudeUsagePreviewState {
        let observedAt = 1_900_000_000
        let usage = ClaudeStatusLineSnapshot(
            observedAt: observedAt,
            model: nil,
            fiveHour: try! ClaudeUsageWindowSnapshot(usedPercent: fiveHourUsed, resetsAt: resetsAt),
            sevenDay: try! ClaudeUsageWindowSnapshot(usedPercent: sevenDayUsed, resetsAt: resetsAt + 10_000)
        )
        return ClaudeUsagePreviewState(
            isEnabled: true,
            cacheSnapshot: ClaudeUsageCacheSnapshot(
                lastEventAt: observedAt,
                lastUsageObservedAt: observedAt,
                staleAfterSeconds: staleAfterSeconds,
                usage: usage,
                issue: nil
            ),
            history: .empty,
            loadIssue: nil
        )
    }
}

@MainActor
private final class RecordingDelivery: UsageNotificationDelivering {
    private var contents: [UsageNotificationContent] = []

    func deliver(_ content: UsageNotificationContent) async throws {
        contents.append(content)
    }

    func deliveredCount() -> Int { contents.count }
    func identifiers() -> [String] { contents.map(\.identifier) }
}
