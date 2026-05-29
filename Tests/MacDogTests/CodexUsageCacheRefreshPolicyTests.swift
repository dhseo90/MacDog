import XCTest
@testable import MacDog

final class CodexUsageCacheRefreshPolicyTests: XCTestCase {
    func testBundledCacheRefreshUsesShortTimeouts() {
        XCTAssertEqual(CodexUsageCacheRefreshPolicy.requestTimeout, 5)
        XCTAssertEqual(CodexUsageCacheRefreshPolicy.processTimeout, 7)
        XCTAssertEqual(CodexUsageCacheRefreshPolicy.minimumRetryInterval, 60)
    }
}
