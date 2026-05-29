import XCTest
@testable import MacDog

final class ScreenSaverLockDisablerTests: XCTestCase {
    func testReportsSystemLockWhenSysadminctlStillRequiresPassword() throws {
        let defaults = UserDefaults(suiteName: "MacDogTests.ScreenSaverLockDisabler.\(UUID().uuidString)")!
        let commandRunner = RecordingScreenLockCommandRunner(systemScreenLockStatus: "screenLock delay is immediate")
        let disabler = ScreenSaverLockDisabler(defaults: defaults, commandRunner: commandRunner)

        XCTAssertThrowsError(try disabler.setScreenLockDisabled(true)) { error in
            XCTAssertEqual(
                error as? ScreenSaverLockDisablerError,
                .systemLockStillEnabled("즉시")
            )
        }

        XCTAssertTrue(commandRunner.commands.contains("/usr/sbin/sysadminctl -screenLock status"))
    }

    func testAcceptsDisabledSystemLockStatus() throws {
        let defaults = UserDefaults(suiteName: "MacDogTests.ScreenSaverLockDisabler.\(UUID().uuidString)")!
        let commandRunner = RecordingScreenLockCommandRunner(systemScreenLockStatus: "screenLock delay is off")
        let disabler = ScreenSaverLockDisabler(defaults: defaults, commandRunner: commandRunner)

        XCTAssertTrue(try disabler.setScreenLockDisabled(true))
        XCTAssertTrue(commandRunner.commands.contains("/usr/sbin/sysadminctl -screenLock status"))
    }
}

private final class RecordingScreenLockCommandRunner: CommandRunning {
    let systemScreenLockStatus: String
    private(set) var commands: [String] = []

    init(systemScreenLockStatus: String) {
        self.systemScreenLockStatus = systemScreenLockStatus
    }

    func run(executablePath: String, arguments: [String]) throws -> CommandResult {
        let command = ([executablePath] + arguments).joined(separator: " ")
        commands.append(command)

        if executablePath == "/usr/bin/defaults",
           arguments.count == 4,
           Array(arguments.prefix(3)) == ["-currentHost", "read", "com.apple.screensaver"] {
            return CommandResult(exitCode: 1, stdout: "", stderr: "does not exist")
        }
        if executablePath == "/usr/bin/defaults",
           arguments.count == 6,
           Array(arguments.prefix(3)) == ["-currentHost", "write", "com.apple.screensaver"],
           arguments[4] == "-int" {
            return CommandResult(exitCode: 0, stdout: "", stderr: "")
        }
        if executablePath == "/usr/sbin/sysadminctl",
           arguments == ["-screenLock", "status"] {
            return CommandResult(exitCode: 0, stdout: "", stderr: systemScreenLockStatus)
        }

        return CommandResult(exitCode: 1, stdout: "", stderr: "unexpected command: \(command)")
    }
}
