import Darwin
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

    func testUsageCacheLaunchAgentRunsOnlyInCodexMode() {
        XCTAssertEqual(UserComponentInstaller.cacheAgentAction(for: .codex), .install)
        XCTAssertEqual(UserComponentInstaller.cacheAgentAction(for: .grok), .remove)
        XCTAssertEqual(UserComponentInstaller.cacheAgentAction(for: .claude), .remove)
        XCTAssertEqual(UserComponentInstaller.grokCacheAgentAction(for: .grok), .install)
        XCTAssertEqual(UserComponentInstaller.grokCacheAgentAction(for: .codex), .remove)
        XCTAssertEqual(UserComponentInstaller.grokCacheAgentAction(for: .claude), .remove)
    }

    func testEnabledProviderSetInstallsMatchingCacheAgentsIndependently() {
        let dual = UsageProviderSelection(
            enabled: [.codex, .grok],
            main: .grok,
            detailGraphVisible: true
        )
        let grokOnly = UsageProviderSelection(enabled: .grok, main: .grok, detailGraphVisible: true)
        let codexOnly = UsageProviderSelection(enabled: .codex, main: .codex, detailGraphVisible: true)

        XCTAssertEqual(UserComponentInstaller.cacheAgentAction(for: dual), .install)
        XCTAssertEqual(UserComponentInstaller.grokCacheAgentAction(for: dual), .install)
        XCTAssertEqual(UserComponentInstaller.cacheAgentAction(for: grokOnly), .remove)
        XCTAssertEqual(UserComponentInstaller.grokCacheAgentAction(for: grokOnly), .install)
        XCTAssertEqual(UserComponentInstaller.cacheAgentAction(for: codexOnly), .install)
        XCTAssertEqual(UserComponentInstaller.grokCacheAgentAction(for: codexOnly), .remove)
    }

    func testClaudeModeRemovesCodexCacheLaunchAgentWithoutTouchingUsageCache() throws {
        let home = try makeTemporaryHome()
        defer { try? fileManager.removeItem(at: home) }
        let launchAgents = home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
        let plist = launchAgents.appendingPathComponent("\(UserComponentInstaller.cacheLabel).plist")
        let usageCache = home.appendingPathComponent("Library/Application Support/MacDog/usage.json")
        try fileManager.createDirectory(at: launchAgents, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: usageCache.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("plist".utf8).write(to: plist)
        try Data("cache".utf8).write(to: usageCache)
        var calls: [[String]] = []
        let installer = UserComponentInstaller(
            appBundleURL: URL(fileURLWithPath: "/Applications/MacDog.app", isDirectory: true),
            homeDirectory: home,
            launchctlRunner: { arguments in
                calls.append(arguments)
                return ""
            }
        )

        try installer.synchronizeUsageCacheAgent(for: .claude)

        XCTAssertFalse(fileManager.fileExists(atPath: plist.path))
        XCTAssertEqual(try String(contentsOf: usageCache, encoding: .utf8), "cache")
        XCTAssertTrue(calls.contains(["bootout", "gui/\(getuid())/\(UserComponentInstaller.cacheLabel)"]))
    }

    func testClaudeModeFallsBackToPlistBootoutWhenLabelBootoutFails() throws {
        let home = try makeTemporaryHome()
        defer { try? fileManager.removeItem(at: home) }
        let plist = home
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(UserComponentInstaller.cacheLabel).plist")
        try fileManager.createDirectory(at: plist.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("plist".utf8).write(to: plist)
        var calls: [[String]] = []
        let installer = UserComponentInstaller(
            appBundleURL: URL(fileURLWithPath: "/Applications/MacDog.app", isDirectory: true),
            homeDirectory: home,
            launchctlRunner: { arguments in
                calls.append(arguments)
                if arguments == ["bootout", "gui/\(getuid())/\(UserComponentInstaller.cacheLabel)"] {
                    throw UserComponentInstallerError.launchctlFailed(arguments.joined(separator: " "), "not found")
                }
                return ""
            }
        )

        try installer.synchronizeUsageCacheAgent(for: .claude)

        XCTAssertFalse(fileManager.fileExists(atPath: plist.path))
        XCTAssertTrue(calls.contains(["bootout", "gui/\(getuid())", plist.path]))
    }

    func testClaudeModePreservesPlistAndThrowsWhenLoadedJobCannotBeRemoved() throws {
        let home = try makeTemporaryHome()
        defer { try? fileManager.removeItem(at: home) }
        let plist = home
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(UserComponentInstaller.cacheLabel).plist")
        try fileManager.createDirectory(at: plist.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("plist".utf8).write(to: plist)
        let installer = UserComponentInstaller(
            appBundleURL: URL(fileURLWithPath: "/Applications/MacDog.app", isDirectory: true),
            homeDirectory: home,
            launchctlRunner: { arguments in
                if arguments.first == "print" {
                    return "loaded"
                }
                throw UserComponentInstallerError.launchctlFailed(arguments.joined(separator: " "), "permission denied")
            }
        )

        XCTAssertThrowsError(try installer.synchronizeUsageCacheAgent(for: .claude))
        XCTAssertTrue(fileManager.fileExists(atPath: plist.path))
    }

    func testClaudeModeRemovesPlistWhenBootoutConfirmsJobWasAlreadyMissing() throws {
        let home = try makeTemporaryHome()
        defer { try? fileManager.removeItem(at: home) }
        let plist = home
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(UserComponentInstaller.cacheLabel).plist")
        try fileManager.createDirectory(at: plist.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("plist".utf8).write(to: plist)
        let installer = UserComponentInstaller(
            appBundleURL: URL(fileURLWithPath: "/Applications/MacDog.app", isDirectory: true),
            homeDirectory: home,
            launchctlRunner: { arguments in
                throw UserComponentInstallerError.launchctlFailed(
                    arguments.joined(separator: " "),
                    "Could not find specified service"
                )
            }
        )

        try installer.synchronizeUsageCacheAgent(for: .claude)

        XCTAssertFalse(fileManager.fileExists(atPath: plist.path))
    }

    func testClaudeModePreservesPlistWhenLoadedStateCannotBeVerified() throws {
        let home = try makeTemporaryHome()
        defer { try? fileManager.removeItem(at: home) }
        let plist = home
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(UserComponentInstaller.cacheLabel).plist")
        try fileManager.createDirectory(at: plist.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("plist".utf8).write(to: plist)
        let installer = UserComponentInstaller(
            appBundleURL: URL(fileURLWithPath: "/Applications/MacDog.app", isDirectory: true),
            homeDirectory: home,
            launchctlRunner: { arguments in
                throw UserComponentInstallerError.launchctlFailed(
                    arguments.joined(separator: " "),
                    arguments.first == "print" ? "permission denied" : "bootout failed"
                )
            }
        )

        XCTAssertThrowsError(try installer.synchronizeUsageCacheAgent(for: .claude))
        XCTAssertTrue(fileManager.fileExists(atPath: plist.path))
    }

    func testCodexModeCreatesCacheLaunchAgentAfterClaudeMode() throws {
        let home = try makeTemporaryHome()
        defer { try? fileManager.removeItem(at: home) }
        var calls: [[String]] = []
        let installer = UserComponentInstaller(
            appBundleURL: URL(fileURLWithPath: "/Applications/MacDog.app", isDirectory: true),
            homeDirectory: home,
            launchctlRunner: { arguments in
                calls.append(arguments)
                return ""
            }
        )

        try installer.synchronizeUsageCacheAgent(for: .codex)

        let plist = home
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(UserComponentInstaller.cacheLabel).plist")
        let data = try Data(contentsOf: plist)
        let propertyList = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
        XCTAssertEqual(propertyList["StartInterval"] as? Int, 60)
        XCTAssertTrue(calls.contains(["bootstrap", "gui/\(getuid())", plist.path]))
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
        XCTAssertNil(plist["KeepAlive"])
        XCTAssertEqual(plist["StartInterval"] as? Int, 60)
        XCTAssertEqual(
            plist["ProgramArguments"] as? [String],
            [
                "/Applications/MacDog.app/Contents/MacOS/codex-usage",
                "status",
                "--write-cache",
                "--timeout",
                "15"
            ]
        )
        XCTAssertEqual(plist["StandardOutPath"] as? String, "/Users/test/Library/Logs/MacDog/cache.out.log")
        XCTAssertEqual(plist["StandardErrorPath"] as? String, "/Users/test/Library/Logs/MacDog/cache.err.log")
    }

    func testGrokCacheLaunchAgentPlistRunsBundledGrokWriter() throws {
        let data = try UserComponentInstaller.grokCachePlistData(
            appCLIPath: "/Applications/MacDog.app/Contents/MacOS/macdog-grok-usage",
            logDirectoryPath: "/Users/test/Library/Logs/MacDog"
        )
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )

        XCTAssertEqual(plist["Label"] as? String, "com.dhseo.macdog.grok-usage-cache")
        XCTAssertEqual(plist["StartInterval"] as? Int, 60)
        XCTAssertEqual(
            plist["ProgramArguments"] as? [String],
            [
                "/Applications/MacDog.app/Contents/MacOS/macdog-grok-usage",
                "status",
                "--write-cache",
                "--timeout",
                "15"
            ]
        )
    }

    func testGrokModeInstallsGrokAgentAndRemovesCodexAgent() throws {
        let home = try makeTemporaryHome()
        defer { try? fileManager.removeItem(at: home) }
        let app = try makeTemporaryAppBundle(in: home)
        var calls: [[String]] = []
        let installer = UserComponentInstaller(
            appBundleURL: app,
            homeDirectory: home,
            launchctlRunner: { arguments in
                calls.append(arguments)
                return ""
            }
        )

        try installer.synchronizeUsageCacheAgent(for: .grok)

        let grokPlist = home
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(UserComponentInstaller.grokCacheLabel).plist")
        let codexPlist = home
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(UserComponentInstaller.cacheLabel).plist")
        XCTAssertTrue(fileManager.fileExists(atPath: grokPlist.path))
        XCTAssertFalse(fileManager.fileExists(atPath: codexPlist.path))
        XCTAssertTrue(calls.contains(["bootstrap", "gui/\(getuid())", grokPlist.path]))
    }

    func testBothEnabledProvidersInstallBothLaunchAgentsWithoutRemovingTheOther() throws {
        let home = try makeTemporaryHome()
        defer { try? fileManager.removeItem(at: home) }
        let app = try makeTemporaryAppBundle(in: home)
        var calls: [[String]] = []
        let installer = UserComponentInstaller(
            appBundleURL: app,
            homeDirectory: home,
            launchctlRunner: { arguments in
                calls.append(arguments)
                return ""
            }
        )
        let dual = UsageProviderSelection(
            enabled: [.codex, .grok],
            main: .codex,
            detailGraphVisible: true
        )

        try installer.synchronizeUsageCacheAgent(for: dual)

        let grokPlist = home
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(UserComponentInstaller.grokCacheLabel).plist")
        let codexPlist = home
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(UserComponentInstaller.cacheLabel).plist")
        XCTAssertTrue(fileManager.fileExists(atPath: grokPlist.path))
        XCTAssertTrue(fileManager.fileExists(atPath: codexPlist.path))
        XCTAssertTrue(calls.contains(["bootstrap", "gui/\(getuid())", grokPlist.path]))
        XCTAssertTrue(calls.contains(["bootstrap", "gui/\(getuid())", codexPlist.path]))
    }

    func testDisablingCodexRemovesOnlyCodexAgentWhenGrokStaysEnabled() throws {
        let home = try makeTemporaryHome()
        defer { try? fileManager.removeItem(at: home) }
        let app = try makeTemporaryAppBundle(in: home)
        let installer = UserComponentInstaller(
            appBundleURL: app,
            homeDirectory: home,
            launchctlRunner: { _ in "" }
        )
        let dual = UsageProviderSelection(
            enabled: [.codex, .grok],
            main: .codex,
            detailGraphVisible: true
        )
        let grokOnly = UsageProviderSelection(enabled: .grok, main: .grok, detailGraphVisible: true)

        try installer.synchronizeUsageCacheAgent(for: dual)
        try installer.synchronizeUsageCacheAgent(for: grokOnly)

        let grokPlist = home
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(UserComponentInstaller.grokCacheLabel).plist")
        let codexPlist = home
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(UserComponentInstaller.cacheLabel).plist")
        XCTAssertTrue(fileManager.fileExists(atPath: grokPlist.path))
        XCTAssertFalse(fileManager.fileExists(atPath: codexPlist.path))
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
                "15"
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

    private func makeTemporaryAppBundle(in home: URL) throws -> URL {
        let app = home.appendingPathComponent("Applications/MacDog.app", isDirectory: true)
        let macos = app.appendingPathComponent("Contents/MacOS", isDirectory: true)
        try fileManager.createDirectory(at: macos, withIntermediateDirectories: true)
        for name in ["codex-usage", "macdog-grok-usage"] {
            let url = macos.appendingPathComponent(name)
            try Data("#!/bin/sh\nexit 0\n".utf8).write(to: url)
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
        return app
    }

    private func cliSymlinkURL(home: URL) -> URL {
        home
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("codex-usage")
    }
}
