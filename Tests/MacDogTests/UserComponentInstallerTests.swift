import XCTest
@testable import MacDog

final class UserComponentInstallerTests: XCTestCase {
    func testManagedInstallLocationsAreLimitedToApplicationsFolders() {
        let home = URL(fileURLWithPath: "/Users/test", isDirectory: true)

        XCTAssertTrue(UserComponentInstaller.shouldManage(
            appBundleURL: URL(fileURLWithPath: "/Applications/MacDog.app", isDirectory: true),
            homeDirectory: home
        ))
        XCTAssertTrue(UserComponentInstaller.shouldManage(
            appBundleURL: URL(fileURLWithPath: "/Users/test/Applications/MacDog.app", isDirectory: true),
            homeDirectory: home
        ))
        XCTAssertFalse(UserComponentInstaller.shouldManage(
            appBundleURL: URL(fileURLWithPath: "/Users/test/workspace/MacDog/dist/MacDog.app", isDirectory: true),
            homeDirectory: home
        ))
    }

    func testCacheLaunchAgentPlistRunsBundledCLIAtSixtySecondCadence() throws {
        let data = try UserComponentInstaller.cachePlistData(
            appCLIPath: "/Applications/MacDog.app/Contents/MacOS/codex-usage",
            logDirectoryPath: "/Users/test/Library/Logs/MacDog"
        )
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )

        XCTAssertEqual(plist["Label"] as? String, "com.dhseo.macdog.usage-cache")
        XCTAssertEqual(plist["RunAtLoad"] as? Bool, true)
        XCTAssertEqual(plist["KeepAlive"] as? Bool, true)
        XCTAssertEqual(
            plist["ProgramArguments"] as? [String],
            [
                "/Applications/MacDog.app/Contents/MacOS/codex-usage",
                "status",
                "--write-cache",
                "--timeout",
                "5",
                "--watch",
                "60"
            ]
        )
        XCTAssertEqual(plist["StandardOutPath"] as? String, "/Users/test/Library/Logs/MacDog/cache.out.log")
        XCTAssertEqual(plist["StandardErrorPath"] as? String, "/Users/test/Library/Logs/MacDog/cache.err.log")
    }
}
