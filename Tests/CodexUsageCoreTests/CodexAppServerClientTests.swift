import XCTest
@testable import CodexUsageCore

final class CodexAppServerClientTests: XCTestCase {
    func testDefaultWorkingDirectoryUsesTemporaryDirectory() {
        XCTAssertEqual(CodexAppServerClient.defaultWorkingDirectoryURL.path, "/tmp")
    }
}
