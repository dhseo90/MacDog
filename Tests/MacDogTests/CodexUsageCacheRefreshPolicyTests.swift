import XCTest
@testable import MacDog

final class CodexUsageCacheRefreshPolicyTests: XCTestCase {
    func testBundledCacheRefreshUsesShortTimeouts() {
        XCTAssertEqual(CodexUsageCacheRefreshPolicy.cacheReadInterval, 60)
        XCTAssertEqual(CodexUsageCacheRefreshPolicy.cacheReadTolerance, 6)
        XCTAssertLessThanOrEqual(
            CodexUsageCacheRefreshPolicy.cacheReadTolerance,
            CodexUsageCacheRefreshPolicy.cacheReadInterval * 0.1
        )
        XCTAssertEqual(CodexUsageCacheRefreshPolicy.requestTimeout, 5)
        XCTAssertEqual(CodexUsageCacheRefreshPolicy.processTimeout, 7)
        XCTAssertEqual(CodexUsageCacheRefreshPolicy.minimumRetryInterval, 60)
    }
}
