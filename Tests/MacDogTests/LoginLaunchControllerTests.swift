import Darwin
import XCTest
@testable import MacDog

final class LoginLaunchControllerTests: XCTestCase {
    func testEnablingRegistersMainAppLoginItemAndRemovesLegacyMonitorPlist() throws {
        let root = try temporaryDirectory()
        let home = root.appendingPathComponent("Home", isDirectory: true)
        let legacyPlist = home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
            .appendingPathComponent("com.dhseo.macdog.monitor.plist")
        try FileManager.default.createDirectory(at: legacyPlist.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("legacy".utf8).write(to: legacyPlist)
        let service = RecordingLoginLaunchService(status: .notRegistered)
        var launchctlArguments: [[String]] = []
        let controller = LoginLaunchController(
            appBundleURL: URL(fileURLWithPath: "/Applications/MacDog.app", isDirectory: true),
            homeDirectory: home,
            service: service,
            launchctlRunner: { launchctlArguments.append($0) }
        )

        try controller.setEnabled(true)

        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertEqual(service.unregisterCallCount, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyPlist.path))
        XCTAssertEqual(launchctlArguments, [["bootout", "gui/\(getuid())", legacyPlist.path]])
    }

    func testDisablingUnregistersMainAppLoginItem() throws {
        let root = try temporaryDirectory()
        let service = RecordingLoginLaunchService(status: .enabled)
        let controller = LoginLaunchController(
            homeDirectory: root,
            service: service,
            launchctlRunner: { _ in }
        )

        try controller.setEnabled(false)

        XCTAssertEqual(service.registerCallCount, 0)
        XCTAssertEqual(service.unregisterCallCount, 1)
    }

    private func temporaryDirectory() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("MacDogLoginLaunchControllerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

private final class RecordingLoginLaunchService: LoginLaunchServicing {
    var status: LoginLaunchStatus
    private(set) var registerCallCount = 0
    private(set) var unregisterCallCount = 0

    init(status: LoginLaunchStatus) {
        self.status = status
    }

    func register() throws {
        registerCallCount += 1
        status = .enabled
    }

    func unregister() throws {
        unregisterCallCount += 1
        status = .notRegistered
    }
}
