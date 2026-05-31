import XCTest
import MacDogPrivilegedHelperSupport
@testable import MacDog

final class ScreenSaverLockDisablerTests: XCTestCase {
    func testAcceptsDefaultsDisableWhenSysadminctlStillRequiresPassword() throws {
        let defaults = UserDefaults(suiteName: "MacDogTests.ScreenSaverLockDisabler.\(UUID().uuidString)")!
        let commandRunner = RecordingScreenLockCommandRunner(systemScreenLockStatus: "screenLock delay is immediate")
        let disabler = ScreenSaverLockDisabler(defaults: defaults, commandRunner: commandRunner, helperController: nil)

        XCTAssertTrue(try disabler.setScreenLockDisabled(true))

        XCTAssertFalse(commandRunner.commands.contains("/usr/sbin/sysadminctl -screenLock status"))
    }

    func testAcceptsDisabledSystemLockStatus() throws {
        let defaults = UserDefaults(suiteName: "MacDogTests.ScreenSaverLockDisabler.\(UUID().uuidString)")!
        let commandRunner = RecordingScreenLockCommandRunner(systemScreenLockStatus: "screenLock delay is off")
        let disabler = ScreenSaverLockDisabler(defaults: defaults, commandRunner: commandRunner, helperController: nil)

        XCTAssertTrue(try disabler.setScreenLockDisabled(true))
        XCTAssertFalse(commandRunner.commands.contains("/usr/sbin/sysadminctl -screenLock status"))
    }

    func testInstalledHelperSetsSystemScreenLockOffAndRestoresOriginalDelay() throws {
        let defaults = UserDefaults(suiteName: "MacDogTests.ScreenSaverLockDisabler.\(UUID().uuidString)")!
        let commandRunner = RecordingScreenLockCommandRunner(systemScreenLockStatuses: [
            "screenLock delay is off"
        ])
        let helperController = RecordingScreenLockHelperController(
            isInstalled: true,
            readValues: [.immediate]
        )
        let disabler = ScreenSaverLockDisabler(
            defaults: defaults,
            commandRunner: commandRunner,
            helperController: helperController
        )

        XCTAssertTrue(try disabler.setScreenLockDisabled(true))
        XCTAssertFalse(try disabler.setScreenLockDisabled(false))

        XCTAssertEqual(helperController.readRequests, 1)
        XCTAssertEqual(helperController.setRequests, [.off, .immediate])
    }

    func testInstalledHelperStoresOriginalDelayEvenAfterPreviousDefaultsOnlyAttempt() throws {
        let defaults = UserDefaults(suiteName: "MacDogTests.ScreenSaverLockDisabler.\(UUID().uuidString)")!
        let firstCommandRunner = RecordingScreenLockCommandRunner(systemScreenLockStatus: "screenLock delay is immediate")
        let firstDisabler = ScreenSaverLockDisabler(
            defaults: defaults,
            commandRunner: firstCommandRunner,
            helperController: nil
        )

        XCTAssertTrue(try firstDisabler.setScreenLockDisabled(true))

        let helperController = RecordingScreenLockHelperController(
            isInstalled: true,
            readValues: [.seconds(120)]
        )
        let secondDisabler = ScreenSaverLockDisabler(
            defaults: defaults,
            commandRunner: RecordingScreenLockCommandRunner(systemScreenLockStatus: "screenLock delay is off"),
            helperController: helperController
        )

        XCTAssertTrue(try secondDisabler.setScreenLockDisabled(true))
        XCTAssertFalse(try secondDisabler.setScreenLockDisabled(false))
        XCTAssertEqual(helperController.setRequests, [.off, .seconds(120)])
    }

    func testInstalledHelperScreenLockSetFailureDoesNotCreateWarning() throws {
        let defaults = UserDefaults(suiteName: "MacDogTests.ScreenSaverLockDisabler.\(UUID().uuidString)")!
        let helperController = RecordingScreenLockHelperController(
            isInstalled: true,
            readValues: [.immediate],
            setError: TestScreenLockError.denied
        )
        let disabler = ScreenSaverLockDisabler(
            defaults: defaults,
            commandRunner: RecordingScreenLockCommandRunner(systemScreenLockStatus: "screenLock delay is immediate"),
            helperController: helperController
        )

        XCTAssertTrue(try disabler.setScreenLockDisabled(true))
        XCTAssertEqual(helperController.setRequests, [.off])
    }

    func testInstalledHelperDoesNotSetUnsupportedOriginalSystemDelay() {
        let defaults = UserDefaults(suiteName: "MacDogTests.ScreenSaverLockDisabler.\(UUID().uuidString)")!
        let helperController = RecordingScreenLockHelperController(
            isInstalled: true,
            readValues: [.unknown("managed")]
        )
        let disabler = ScreenSaverLockDisabler(
            defaults: defaults,
            commandRunner: RecordingScreenLockCommandRunner(systemScreenLockStatus: "screenLock delay is immediate"),
            helperController: helperController
        )

        XCTAssertThrowsError(try disabler.setScreenLockDisabled(true)) { error in
            XCTAssertEqual(error as? ScreenSaverLockDisablerError, .unsupportedSystemLockStatus("managed"))
        }
        XCTAssertTrue(helperController.setRequests.isEmpty)
    }

    func testXPCHelperControllerReadsAndSetsScreenLockDelay() throws {
        let readSender = RecordingScreenLockPrivilegedHelperRequestSender(
            result: .success(PrivilegedHelperResponse(status: .success, screenLockDelay: .immediate))
        )
        let readController = XPCScreenLockHelperController(
            requestSender: readSender,
            installSnapshotProvider: {
                PrivilegedHelperInstallSnapshot(helperToolExists: true, launchDaemonExists: true)
            },
            timeoutSeconds: 0.01
        )

        XCTAssertEqual(try readController.readScreenLockDelay(), .immediate)
        XCTAssertEqual(readSender.commands, [.readScreenLockDelay])

        let setSender = RecordingScreenLockPrivilegedHelperRequestSender(
            result: .success(PrivilegedHelperResponse(status: .success, screenLockDelay: .off))
        )
        let setController = XPCScreenLockHelperController(
            requestSender: setSender,
            installSnapshotProvider: {
                PrivilegedHelperInstallSnapshot(helperToolExists: true, launchDaemonExists: true)
            },
            timeoutSeconds: 0.01
        )

        try setController.setScreenLockDelay(.off)
        XCTAssertEqual(setSender.commands, [.setScreenLockDelay(.off)])
    }
}

private enum TestScreenLockError: LocalizedError {
    case denied

    var errorDescription: String? {
        "screenLock 변경이 허용되지 않습니다."
    }
}

private final class RecordingScreenLockCommandRunner: CommandRunning {
    private var systemScreenLockStatuses: [String]
    private(set) var commands: [String] = []

    init(systemScreenLockStatus: String) {
        self.systemScreenLockStatuses = [systemScreenLockStatus]
    }

    init(systemScreenLockStatuses: [String]) {
        self.systemScreenLockStatuses = systemScreenLockStatuses
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
        if executablePath == "/usr/bin/defaults",
           arguments.count == 4,
           Array(arguments.prefix(3)) == ["-currentHost", "delete", "com.apple.screensaver"] {
            return CommandResult(exitCode: 0, stdout: "", stderr: "")
        }
        if executablePath == "/usr/sbin/sysadminctl",
           arguments == ["-screenLock", "status"] {
            let status = systemScreenLockStatuses.isEmpty ? "screenLock delay is off" : systemScreenLockStatuses.removeFirst()
            return CommandResult(exitCode: 0, stdout: "", stderr: status)
        }

        return CommandResult(exitCode: 1, stdout: "", stderr: "unexpected command: \(command)")
    }
}

private final class RecordingScreenLockHelperController: ScreenLockHelperControlling {
    let isInstalled: Bool
    private var readValues: [ScreenLockDelay]
    private let readError: Error?
    private let setError: Error?
    private(set) var readRequests = 0
    private(set) var setRequests: [ScreenLockDelay] = []

    init(
        isInstalled: Bool,
        readValues: [ScreenLockDelay] = [],
        readError: Error? = nil,
        setError: Error? = nil
    ) {
        self.isInstalled = isInstalled
        self.readValues = readValues
        self.readError = readError
        self.setError = setError
    }

    func readScreenLockDelay() throws -> ScreenLockDelay {
        readRequests += 1
        if let readError {
            throw readError
        }
        return readValues.isEmpty ? .off : readValues.removeFirst()
    }

    func setScreenLockDelay(_ delay: ScreenLockDelay) throws {
        setRequests.append(delay)
        if let setError {
            throw setError
        }
    }
}

private final class RecordingScreenLockPrivilegedHelperRequestSender: PrivilegedHelperRequestSending {
    private let result: Result<PrivilegedHelperResponse, Error>
    private(set) var commands: [PrivilegedHelperCommand] = []

    init(result: Result<PrivilegedHelperResponse, Error>) {
        self.result = result
    }

    func send(
        _ request: PrivilegedHelperRequest,
        completion: @escaping (Result<PrivilegedHelperResponse, Error>) -> Void
    ) {
        commands.append(request.command)
        completion(result)
    }
}
