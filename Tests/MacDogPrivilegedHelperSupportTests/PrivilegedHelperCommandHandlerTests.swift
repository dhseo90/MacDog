import XCTest
@testable import MacDogPrivilegedHelperSupport

final class PrivilegedHelperCommandHandlerTests: XCTestCase {
    func testRejectsUnsupportedProtocolBeforeRunningCommand() {
        let runner = RecordingPrivilegedHelperRunner()
        let handler = PrivilegedHelperCommandHandler(runner: runner)
        let response = handler.handle(PrivilegedHelperRequest(protocolVersion: 999, command: .readSleepDisabled))

        XCTAssertEqual(response.status, .unsupportedProtocol)
        XCTAssertTrue(runner.invocations.isEmpty)
    }

    func testReadsSleepDisabledValue() {
        let runner = RecordingPrivilegedHelperRunner(
            results: [
                PrivilegedHelperExecutionResult(
                    exitCode: 0,
                    stdout: "System-wide power settings:\n SleepDisabled 1\n",
                    stderr: ""
                )
            ]
        )
        let handler = PrivilegedHelperCommandHandler(runner: runner)
        let response = handler.handle(PrivilegedHelperRequest(command: .readSleepDisabled))

        XCTAssertEqual(response.status, .success)
        XCTAssertEqual(response.sleepDisabled, true)
        XCTAssertEqual(runner.invocations, [
            PMSetInvocation(executablePath: "/usr/bin/pmset", arguments: ["-g", "live"])
        ])
    }

    func testSetsSleepDisabledUsingAllowlistedPmsetInvocation() {
        let runner = RecordingPrivilegedHelperRunner(
            results: [
                PrivilegedHelperExecutionResult(exitCode: 0, stdout: "", stderr: "")
            ]
        )
        let handler = PrivilegedHelperCommandHandler(runner: runner)
        let response = handler.handle(PrivilegedHelperRequest(command: .setSleepDisabled(false)))

        XCTAssertEqual(response.status, .success)
        XCTAssertEqual(response.sleepDisabled, false)
        XCTAssertEqual(runner.invocations, [
            PMSetInvocation(executablePath: "/usr/bin/pmset", arguments: ["-a", "disablesleep", "0"])
        ])
    }

    func testReadsScreenLockDelayUsingAllowlistedSysadminctlInvocation() {
        let runner = RecordingPrivilegedHelperRunner(
            results: [
                PrivilegedHelperExecutionResult(exitCode: 0, stdout: "", stderr: "screenLock delay is immediate")
            ]
        )
        let handler = PrivilegedHelperCommandHandler(runner: runner)
        let response = handler.handle(PrivilegedHelperRequest(command: .readScreenLockDelay))

        XCTAssertEqual(response.status, .success)
        XCTAssertEqual(response.screenLockDelay, .immediate)
        XCTAssertEqual(runner.invocations, [
            PMSetInvocation(executablePath: "/usr/sbin/sysadminctl", arguments: ["-screenLock", "status"])
        ])
    }

    func testSetsScreenLockDelayUsingAllowlistedSysadminctlInvocation() {
        let runner = RecordingPrivilegedHelperRunner(
            results: [
                PrivilegedHelperExecutionResult(exitCode: 0, stdout: "", stderr: "")
            ]
        )
        let handler = PrivilegedHelperCommandHandler(runner: runner)
        let response = handler.handle(PrivilegedHelperRequest(command: .setScreenLockDelay(.off)))

        XCTAssertEqual(response.status, .success)
        XCTAssertEqual(response.screenLockDelay, .off)
        XCTAssertEqual(runner.invocations, [
            PMSetInvocation(executablePath: "/usr/sbin/sysadminctl", arguments: ["-screenLock", "off"])
        ])
    }

    func testRejectsUnsupportedScreenLockDelayBeforeRunningCommand() {
        let runner = RecordingPrivilegedHelperRunner()
        let handler = PrivilegedHelperCommandHandler(runner: runner)
        let response = handler.handle(PrivilegedHelperRequest(command: .setScreenLockDelay(.unknown("managed"))))

        XCTAssertEqual(response.status, .unsupportedCommand)
        XCTAssertEqual(response.screenLockDelay, nil)
        XCTAssertTrue(runner.invocations.isEmpty)
    }

    func testCommandFailureReturnsRedactedFailureSummary() {
        let runner = RecordingPrivilegedHelperRunner(
            results: [
                PrivilegedHelperExecutionResult(exitCode: 1, stdout: "ignored", stderr: "not permitted")
            ]
        )
        let handler = PrivilegedHelperCommandHandler(runner: runner)
        let response = handler.handle(PrivilegedHelperRequest(command: .setSleepDisabled(true)))

        XCTAssertEqual(response.status, .failed)
        XCTAssertEqual(response.sleepDisabled, nil)
        XCTAssertEqual(response.errorMessage, "/usr/bin/pmset -a disablesleep 1 실패: not permitted")
    }

    func testParserFailureDoesNotExposeRawOutput() {
        let runner = RecordingPrivilegedHelperRunner(
            results: [
                PrivilegedHelperExecutionResult(exitCode: 0, stdout: "unexpected output", stderr: "")
            ]
        )
        let handler = PrivilegedHelperCommandHandler(runner: runner)
        let response = handler.handle(PrivilegedHelperRequest(command: .readSleepDisabled))

        XCTAssertEqual(response.status, .failed)
        XCTAssertEqual(response.sleepDisabled, nil)
        XCTAssertEqual(response.errorMessage, "/usr/bin/pmset -g live 실패: SleepDisabled 값을 찾을 수 없습니다.")
    }
}

private final class RecordingPrivilegedHelperRunner: PrivilegedHelperCommandRunning, @unchecked Sendable {
    private var results: [PrivilegedHelperExecutionResult]
    private(set) var invocations: [PMSetInvocation] = []

    init(results: [PrivilegedHelperExecutionResult] = []) {
        self.results = results
    }

    func run(_ invocation: PMSetInvocation) throws -> PrivilegedHelperExecutionResult {
        invocations.append(invocation)
        return results.isEmpty
            ? PrivilegedHelperExecutionResult(exitCode: 0, stdout: "", stderr: "")
            : results.removeFirst()
    }
}
