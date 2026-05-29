import XCTest
@testable import MacDog

final class PopoverMetricsRefreshPolicyTests: XCTestCase {
    func testLocalMetricsRefreshRunsOncePerSecond() {
        XCTAssertEqual(PopoverMetricsRefreshPolicy.localMetricsInterval, 1)
        XCTAssertLessThanOrEqual(PopoverMetricsRefreshPolicy.localMetricsTolerance, 0.15)
    }

    func testOnlyLocalSystemTabsUseFastRefresh() {
        XCTAssertFalse(PopoverMetricsRefreshPolicy.shouldRefreshLocalMetrics(for: .codex))
        XCTAssertTrue(PopoverMetricsRefreshPolicy.shouldRefreshLocalMetrics(for: .mac))
        XCTAssertTrue(PopoverMetricsRefreshPolicy.shouldRefreshLocalMetrics(for: .sleep))
        XCTAssertTrue(PopoverMetricsRefreshPolicy.shouldRefreshLocalMetrics(for: .battery))
        XCTAssertFalse(PopoverMetricsRefreshPolicy.shouldRefreshLocalMetrics(for: .settings))
    }

    func testUnknownRawValueDoesNotTriggerFastRefresh() {
        XCTAssertFalse(PopoverMetricsRefreshPolicy.shouldRefreshLocalMetrics(forRawValue: nil))
        XCTAssertFalse(PopoverMetricsRefreshPolicy.shouldRefreshLocalMetrics(forRawValue: "unknown"))
        XCTAssertFalse(PopoverMetricsRefreshPolicy.shouldRefreshLocalMetrics(forRawValue: MacDogPopoverModule.codex.rawValue))
        XCTAssertTrue(PopoverMetricsRefreshPolicy.shouldRefreshLocalMetrics(forRawValue: MacDogPopoverModule.mac.rawValue))
    }
}
