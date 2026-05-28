import XCTest
import MacDogPrivilegedHelperSupport
@testable import MacDog

final class ClosedLidSleepDisablerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "MacDogTests.ClosedLidSleepDisabler.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testEnableTurnsOnSleepDisabledAndRestoreTurnsItBackOff() throws {
        let commandRunner = RecordingCommandRunner(
            sleepDisabledValues: [false, true]
        )
        let disabler = PMSetClosedLidSleepDisabler(
            defaults: defaults,
            commandRunner: commandRunner,
            helperController: nil
        )

        XCTAssertTrue(try disabler.setClosedLidSleepDisabled(true))
        XCTAssertFalse(try disabler.setClosedLidSleepDisabled(false))

        XCTAssertEqual(commandRunner.pmsetSetValues, [true, false])
    }

    func testEnableDoesNotOwnAlreadyDisabledSleepState() throws {
        let commandRunner = RecordingCommandRunner(
            sleepDisabledValues: [true, true]
        )
        let disabler = PMSetClosedLidSleepDisabler(
            defaults: defaults,
            commandRunner: commandRunner,
            helperController: nil
        )

        XCTAssertTrue(try disabler.setClosedLidSleepDisabled(true))
        XCTAssertTrue(try disabler.setClosedLidSleepDisabled(false))

        XCTAssertTrue(commandRunner.pmsetSetValues.isEmpty)
    }

    func testUnsupportedOutputThrowsClearError() {
        let commandRunner = RecordingCommandRunner(
            customLiveOutput: "System-wide power settings:\n sleep 1\n"
        )
        let disabler = PMSetClosedLidSleepDisabler(
            defaults: defaults,
            commandRunner: commandRunner,
            helperController: nil
        )

        XCTAssertThrowsError(try disabler.setClosedLidSleepDisabled(true)) { error in
            XCTAssertEqual(error as? ClosedLidSleepDisablerError, .unsupported)
        }
    }

    func testInstalledHelperHandlesReadAndSetBeforeAppleScriptFallback() throws {
        let commandRunner = RecordingCommandRunner()
        let helperController = RecordingClosedLidSleepHelperController(
            isInstalled: true,
            readValues: [false, true]
        )
        let disabler = PMSetClosedLidSleepDisabler(
            defaults: defaults,
            commandRunner: commandRunner,
            helperController: helperController
        )

        XCTAssertTrue(try disabler.setClosedLidSleepDisabled(true))
        XCTAssertFalse(try disabler.setClosedLidSleepDisabled(false))

        XCTAssertEqual(helperController.readRequests, 2)
        XCTAssertEqual(helperController.setRequests, [true, false])
        XCTAssertTrue(commandRunner.pmsetSetValues.isEmpty)
        XCTAssertTrue(commandRunner.pmsetReadCount == 0)
    }

    func testHelperSetFailureFallsBackToAppleScriptPath() throws {
        let commandRunner = RecordingCommandRunner()
        let helperController = RecordingClosedLidSleepHelperController(
            isInstalled: true,
            readValues: [false],
            setError: TestHelperError.failed
        )
        let disabler = PMSetClosedLidSleepDisabler(
            defaults: defaults,
            commandRunner: commandRunner,
            helperController: helperController
        )

        XCTAssertTrue(try disabler.setClosedLidSleepDisabled(true))

        XCTAssertEqual(helperController.setRequests, [true])
        XCTAssertEqual(commandRunner.pmsetSetValues, [true])
    }

    func testHelperReadFailureFallsBackToDirectPmsetRead() throws {
        let commandRunner = RecordingCommandRunner(
            sleepDisabledValues: [false]
        )
        let helperController = RecordingClosedLidSleepHelperController(
            isInstalled: true,
            readError: TestHelperError.failed
        )
        let disabler = PMSetClosedLidSleepDisabler(
            defaults: defaults,
            commandRunner: commandRunner,
            helperController: helperController
        )

        XCTAssertTrue(try disabler.setClosedLidSleepDisabled(true))

        XCTAssertEqual(helperController.readRequests, 1)
        XCTAssertEqual(helperController.setRequests, [true])
    }

    func testXPCHelperControllerUsesInstallSnapshotStatus() {
        let requestSender = RecordingPrivilegedHelperRequestSender(
            result: .success(PrivilegedHelperResponse(status: .success, sleepDisabled: false))
        )
        let controller = XPCClosedLidSleepHelperController(
            requestSender: requestSender,
            installSnapshotProvider: { .missing },
            timeoutSeconds: 0.01
        )

        XCTAssertFalse(controller.isInstalled)
    }

    func testXPCHelperControllerReadsSleepDisabled() throws {
        let requestSender = RecordingPrivilegedHelperRequestSender(
            result: .success(PrivilegedHelperResponse(status: .success, sleepDisabled: true))
        )
        let controller = XPCClosedLidSleepHelperController(
            requestSender: requestSender,
            installSnapshotProvider: {
                PrivilegedHelperInstallSnapshot(helperToolExists: true, launchDaemonExists: true)
            },
            timeoutSeconds: 0.01
        )

        XCTAssertTrue(try controller.readSleepDisabled())
        XCTAssertEqual(requestSender.commands, [.readSleepDisabled])
    }

    func testXPCHelperControllerReportsFailedResponse() {
        let requestSender = RecordingPrivilegedHelperRequestSender(
            result: .success(PrivilegedHelperResponse(status: .failed, errorMessage: "boom"))
        )
        let controller = XPCClosedLidSleepHelperController(
            requestSender: requestSender,
            installSnapshotProvider: {
                PrivilegedHelperInstallSnapshot(helperToolExists: true, launchDaemonExists: true)
            },
            timeoutSeconds: 0.01
        )

        XCTAssertThrowsError(try controller.setSleepDisabled(true)) { error in
            XCTAssertEqual(error as? ClosedLidSleepHelperError, .failed("boom"))
        }
        XCTAssertEqual(requestSender.commands, [.setSleepDisabled(true)])
    }

    func testXPCHelperControllerTimesOutWhenCompletionNeverArrives() {
        let requestSender = SilentPrivilegedHelperRequestSender()
        let controller = XPCClosedLidSleepHelperController(
            requestSender: requestSender,
            installSnapshotProvider: {
                PrivilegedHelperInstallSnapshot(helperToolExists: true, launchDaemonExists: true)
            },
            timeoutSeconds: 0.01
        )

        XCTAssertThrowsError(try controller.readSleepDisabled()) { error in
            XCTAssertEqual(error as? ClosedLidSleepHelperError, .timedOut)
        }
        XCTAssertEqual(requestSender.commands, [.readSleepDisabled])
    }
}

private final class RecordingCommandRunner: CommandRunning {
    private var sleepDisabledValues: [Bool]
    private let customLiveOutput: String?
    private(set) var pmsetReadCount = 0
    private(set) var pmsetSetValues: [Bool] = []

    init(
        sleepDisabledValues: [Bool] = [],
        customLiveOutput: String? = nil
    ) {
        self.sleepDisabledValues = sleepDisabledValues
        self.customLiveOutput = customLiveOutput
    }

    func run(executablePath: String, arguments: [String]) throws -> CommandResult {
        if executablePath == "/usr/bin/pmset", arguments == ["-g", "live"] {
            pmsetReadCount += 1
            if let customLiveOutput {
                return CommandResult(exitCode: 0, stdout: customLiveOutput, stderr: "")
            }

            let value = sleepDisabledValues.isEmpty ? false : sleepDisabledValues.removeFirst()
            return CommandResult(
                exitCode: 0,
                stdout: "System-wide power settings:\n SleepDisabled\t\t\(value ? 1 : 0)\n",
                stderr: ""
            )
        }

        if executablePath == "/usr/bin/osascript",
           let script = arguments.last,
           script.contains("disablesleep 1") {
            pmsetSetValues.append(true)
            return CommandResult(exitCode: 0, stdout: "", stderr: "")
        }

        if executablePath == "/usr/bin/osascript",
           let script = arguments.last,
           script.contains("disablesleep 0") {
            pmsetSetValues.append(false)
            return CommandResult(exitCode: 0, stdout: "", stderr: "")
        }

        XCTFail("Unexpected command: \(executablePath) \(arguments)")
        return CommandResult(exitCode: 1, stdout: "", stderr: "unexpected command")
    }
}

private final class RecordingClosedLidSleepHelperController: ClosedLidSleepHelperControlling {
    let isInstalled: Bool
    private var readValues: [Bool]
    private let readError: Error?
    private let setError: Error?
    private(set) var readRequests = 0
    private(set) var setRequests: [Bool] = []

    init(
        isInstalled: Bool,
        readValues: [Bool] = [],
        readError: Error? = nil,
        setError: Error? = nil
    ) {
        self.isInstalled = isInstalled
        self.readValues = readValues
        self.readError = readError
        self.setError = setError
    }

    func readSleepDisabled() throws -> Bool {
        readRequests += 1
        if let readError {
            throw readError
        }
        return readValues.isEmpty ? false : readValues.removeFirst()
    }

    func setSleepDisabled(_ isDisabled: Bool) throws {
        setRequests.append(isDisabled)
        if let setError {
            throw setError
        }
    }
}

private enum TestHelperError: LocalizedError {
    case failed

    var errorDescription: String? {
        "helper failed"
    }
}

private final class RecordingPrivilegedHelperRequestSender: PrivilegedHelperRequestSending {
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

private final class SilentPrivilegedHelperRequestSender: PrivilegedHelperRequestSending {
    private(set) var commands: [PrivilegedHelperCommand] = []

    func send(
        _ request: PrivilegedHelperRequest,
        completion: @escaping (Result<PrivilegedHelperResponse, Error>) -> Void
    ) {
        commands.append(request.command)
    }
}
