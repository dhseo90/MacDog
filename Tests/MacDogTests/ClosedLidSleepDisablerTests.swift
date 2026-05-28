import XCTest
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
            commandRunner: commandRunner
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
            commandRunner: commandRunner
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
            commandRunner: commandRunner
        )

        XCTAssertThrowsError(try disabler.setClosedLidSleepDisabled(true)) { error in
            XCTAssertEqual(error as? ClosedLidSleepDisablerError, .unsupported)
        }
    }
}

private final class RecordingCommandRunner: CommandRunning {
    private var sleepDisabledValues: [Bool]
    private let customLiveOutput: String?
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
