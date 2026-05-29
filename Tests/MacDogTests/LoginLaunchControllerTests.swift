import XCTest
@testable import MacDog

final class LoginLaunchControllerTests: XCTestCase {
    func testMonitorLaunchAgentPlistOpensAppAtLogin() throws {
        let data = try LoginLaunchController.plistData(appBundlePath: "/Users/test/Applications/MacDog.app")
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )

        XCTAssertEqual(plist["Label"] as? String, "com.dhseo.macdog.monitor")
        XCTAssertEqual(plist["RunAtLoad"] as? Bool, true)
        XCTAssertEqual(
            plist["ProgramArguments"] as? [String],
            ["/usr/bin/open", "/Users/test/Applications/MacDog.app"]
        )
    }
}
