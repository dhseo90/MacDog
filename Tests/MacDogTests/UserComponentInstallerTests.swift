import XCTest
@testable import MacDog

final class UserComponentInstallerTests: XCTestCase {
    private let fileManager = FileManager.default

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

    func testCacheLaunchAgentPlistRunsBundledCLIAtSixtySecondCadenceWithoutWidgetMirrorByDefault() throws {
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

    func testCacheLaunchAgentPlistMirrorsWidgetCacheOnlyWhenRequested() throws {
        let data = try UserComponentInstaller.cachePlistData(
            appCLIPath: "/Applications/MacDog.app/Contents/MacOS/codex-usage",
            logDirectoryPath: "/Users/test/Library/Logs/MacDog",
            mirrorWidgetCache: true
        )
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )

        XCTAssertEqual(
            plist["ProgramArguments"] as? [String],
            [
                "/Applications/MacDog.app/Contents/MacOS/codex-usage",
                "status",
                "--write-cache",
                "--mirror-cache",
                "--timeout",
                "5",
                "--watch",
                "60"
            ]
        )
    }

    func testInstallCLISymlinkCreatesMissingLink() throws {
        let home = try makeTemporaryHome()
        defer { try? fileManager.removeItem(at: home) }
        try fileManager.createDirectory(
            at: home.appendingPathComponent("bin", isDirectory: true),
            withIntermediateDirectories: true
        )

        let appBundleURL = URL(fileURLWithPath: "/Applications/MacDog.app", isDirectory: true)
        let installer = UserComponentInstaller(appBundleURL: appBundleURL, homeDirectory: home)

        try installer.installCLISymlink()

        let target = try fileManager.destinationOfSymbolicLink(atPath: cliSymlinkURL(home: home).path)
        XCTAssertEqual(target, "/Applications/MacDog.app/Contents/MacOS/codex-usage")
    }

    func testInstallCLISymlinkReplacesExistingMacDogLink() throws {
        let home = try makeTemporaryHome()
        defer { try? fileManager.removeItem(at: home) }
        let binURL = home.appendingPathComponent("bin", isDirectory: true)
        try fileManager.createDirectory(at: binURL, withIntermediateDirectories: true)
        try fileManager.createSymbolicLink(
            at: cliSymlinkURL(home: home),
            withDestinationURL: URL(fileURLWithPath: "/Users/test/Applications/MacDog.app/Contents/MacOS/codex-usage")
        )

        let appBundleURL = URL(fileURLWithPath: "/Applications/MacDog.app", isDirectory: true)
        let installer = UserComponentInstaller(appBundleURL: appBundleURL, homeDirectory: home)

        try installer.installCLISymlink()

        let target = try fileManager.destinationOfSymbolicLink(atPath: cliSymlinkURL(home: home).path)
        XCTAssertEqual(target, "/Applications/MacDog.app/Contents/MacOS/codex-usage")
    }

    func testInstallCLISymlinkRejectsNonMacDogSymlink() throws {
        let home = try makeTemporaryHome()
        defer { try? fileManager.removeItem(at: home) }
        let binURL = home.appendingPathComponent("bin", isDirectory: true)
        let linkURL = cliSymlinkURL(home: home)
        try fileManager.createDirectory(at: binURL, withIntermediateDirectories: true)
        try fileManager.createSymbolicLink(
            at: linkURL,
            withDestinationURL: URL(fileURLWithPath: "/usr/local/bin/codex-usage")
        )

        let installer = UserComponentInstaller(
            appBundleURL: URL(fileURLWithPath: "/Applications/MacDog.app", isDirectory: true),
            homeDirectory: home
        )

        XCTAssertThrowsError(try installer.installCLISymlink()) { error in
            XCTAssertEqual(
                error as? UserComponentInstallerError,
                .cliSymlinkConflict(path: linkURL.path, existingTarget: "/usr/local/bin/codex-usage")
            )
        }
        XCTAssertEqual(try fileManager.destinationOfSymbolicLink(atPath: linkURL.path), "/usr/local/bin/codex-usage")
    }

    func testInstallCLISymlinkRejectsExistingRegularFile() throws {
        let home = try makeTemporaryHome()
        defer { try? fileManager.removeItem(at: home) }
        let binURL = home.appendingPathComponent("bin", isDirectory: true)
        let linkURL = cliSymlinkURL(home: home)
        try fileManager.createDirectory(at: binURL, withIntermediateDirectories: true)
        try Data("user script".utf8).write(to: linkURL)

        let installer = UserComponentInstaller(
            appBundleURL: URL(fileURLWithPath: "/Applications/MacDog.app", isDirectory: true),
            homeDirectory: home
        )

        XCTAssertThrowsError(try installer.installCLISymlink()) { error in
            XCTAssertEqual(
                error as? UserComponentInstallerError,
                .cliSymlinkConflict(path: linkURL.path, existingTarget: nil)
            )
        }
        XCTAssertEqual(try String(contentsOf: linkURL, encoding: .utf8), "user script")
    }

    private func makeTemporaryHome() throws -> URL {
        let url = fileManager.temporaryDirectory
            .appendingPathComponent("MacDogUserComponentInstallerTests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func cliSymlinkURL(home: URL) -> URL {
        home
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("codex-usage")
    }
}
