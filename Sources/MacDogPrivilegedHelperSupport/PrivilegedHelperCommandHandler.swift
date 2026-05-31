import Foundation

public struct PrivilegedHelperExecutionResult: Equatable, Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }

    public var failureSummary: String {
        let trimmedError = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedError.isEmpty {
            return trimmedError
        }

        let trimmedOutput = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedOutput.isEmpty ? "exit \(exitCode)" : trimmedOutput
    }
}

public protocol PrivilegedHelperCommandRunning {
    func run(_ invocation: PMSetInvocation) throws -> PrivilegedHelperExecutionResult
}

public struct PrivilegedHelperCommandHandler<Runner: PrivilegedHelperCommandRunning>: Sendable where Runner: Sendable {
    private let runner: Runner

    public init(runner: Runner) {
        self.runner = runner
    }

    public func handle(_ request: PrivilegedHelperRequest) -> PrivilegedHelperResponse {
        guard request.protocolVersion == MacDogPrivilegedHelperContract.protocolVersion else {
            return PrivilegedHelperResponse(
                status: .unsupportedProtocol,
                errorMessage: "지원하지 않는 helper protocol입니다: \(request.protocolVersion)"
            )
        }

        switch request.command {
        case .readSleepDisabled:
            return readSleepDisabled()
        case .setSleepDisabled(let sleepDisabled):
            return setSleepDisabled(sleepDisabled)
        case .readScreenLockDelay:
            return readScreenLockDelay()
        case .setScreenLockDelay(let delay):
            return setScreenLockDelay(delay)
        }
    }

    private func readSleepDisabled() -> PrivilegedHelperResponse {
        let invocation = PrivilegedHelperCommandPlanner.pmsetInvocation(for: .readSleepDisabled)

        do {
            let result = try runner.run(invocation)
            guard result.exitCode == 0 else {
                return failedResponse(command: invocation.displayCommand, detail: result.failureSummary)
            }

            return PrivilegedHelperResponse(
                status: .success,
                sleepDisabled: try SleepDisabledLiveParser.parse(result.stdout)
            )
        } catch {
            return failedResponse(command: invocation.displayCommand, detail: error.localizedDescription)
        }
    }

    private func setSleepDisabled(_ sleepDisabled: Bool) -> PrivilegedHelperResponse {
        let invocation = PrivilegedHelperCommandPlanner.pmsetInvocation(for: .setSleepDisabled(sleepDisabled))

        do {
            let result = try runner.run(invocation)
            guard result.exitCode == 0 else {
                return failedResponse(command: invocation.displayCommand, detail: result.failureSummary)
            }

            return PrivilegedHelperResponse(status: .success, sleepDisabled: sleepDisabled)
        } catch {
            return failedResponse(command: invocation.displayCommand, detail: error.localizedDescription)
        }
    }

    private func readScreenLockDelay() -> PrivilegedHelperResponse {
        guard let invocation = PrivilegedHelperCommandPlanner.sysadminctlInvocation(for: .readScreenLockDelay) else {
            return PrivilegedHelperResponse(status: .unsupportedCommand, errorMessage: "지원하지 않는 screenLock 명령입니다.")
        }

        do {
            let result = try runner.run(invocation)
            guard result.exitCode == 0 else {
                return failedResponse(command: invocation.displayCommand, detail: result.failureSummary)
            }

            return PrivilegedHelperResponse(
                status: .success,
                screenLockDelay: ScreenLockDelayParser.parse([result.stdout, result.stderr].joined(separator: "\n"))
            )
        } catch {
            return failedResponse(command: invocation.displayCommand, detail: error.localizedDescription)
        }
    }

    private func setScreenLockDelay(_ delay: ScreenLockDelay) -> PrivilegedHelperResponse {
        guard let invocation = PrivilegedHelperCommandPlanner.sysadminctlInvocation(for: .setScreenLockDelay(delay)) else {
            return PrivilegedHelperResponse(status: .unsupportedCommand, errorMessage: "지원하지 않는 screenLock 값입니다: \(delay.displayLabel)")
        }

        do {
            let result = try runner.run(invocation)
            guard result.exitCode == 0 else {
                return failedResponse(command: invocation.displayCommand, detail: result.failureSummary)
            }

            return PrivilegedHelperResponse(status: .success, screenLockDelay: delay)
        } catch {
            return failedResponse(command: invocation.displayCommand, detail: error.localizedDescription)
        }
    }

    private func failedResponse(command: String, detail: String) -> PrivilegedHelperResponse {
        PrivilegedHelperResponse(
            status: .failed,
            errorMessage: "\(command) 실패: \(detail)"
        )
    }
}

public struct PrivilegedHelperProcessRunner: PrivilegedHelperCommandRunning, Sendable {
    public init() {}

    public func run(_ invocation: PMSetInvocation) throws -> PrivilegedHelperExecutionResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: invocation.executablePath)
        process.arguments = invocation.arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        return PrivilegedHelperExecutionResult(
            exitCode: process.terminationStatus,
            stdout: String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "",
            stderr: String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        )
    }
}
