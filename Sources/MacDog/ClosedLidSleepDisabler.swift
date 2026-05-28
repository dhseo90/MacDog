import Foundation
import MacDogPrivilegedHelperSupport

protocol ClosedLidSleepDisabling {
    @discardableResult
    func setClosedLidSleepDisabled(_ isDisabled: Bool) throws -> Bool
}

struct PMSetClosedLidSleepDisabler: ClosedLidSleepDisabling {
    private static let changedByMacDogKey = "closedLidSleepDisabledByMacDog"
    private static let originalSleepDisabledKey = "closedLidSleepOriginalDisabled"

    private let defaults: UserDefaults
    private let commandRunner: CommandRunning
    private let helperController: ClosedLidSleepHelperControlling?

    init(
        defaults: UserDefaults = .standard,
        commandRunner: CommandRunning = ProcessCommandRunner(),
        helperController: ClosedLidSleepHelperControlling? = XPCClosedLidSleepHelperController()
    ) {
        self.defaults = defaults
        self.commandRunner = commandRunner
        self.helperController = helperController
    }

    @discardableResult
    func setClosedLidSleepDisabled(_ isDisabled: Bool) throws -> Bool {
        if isDisabled {
            return try disableClosedLidSleep()
        }
        return try restoreClosedLidSleep()
    }

    private func disableClosedLidSleep() throws -> Bool {
        let currentValue = try currentSleepDisabledValue()
        if currentValue {
            return true
        }

        defaults.set(currentValue, forKey: Self.originalSleepDisabledKey)
        defaults.set(true, forKey: Self.changedByMacDogKey)

        do {
            try setSleepDisabledValue(true)
            return true
        } catch {
            clearStoredState()
            throw error
        }
    }

    private func restoreClosedLidSleep() throws -> Bool {
        guard defaults.bool(forKey: Self.changedByMacDogKey) else {
            return try currentSleepDisabledValue()
        }

        let originalValue: Bool
        if defaults.object(forKey: Self.originalSleepDisabledKey) != nil {
            originalValue = defaults.bool(forKey: Self.originalSleepDisabledKey)
        } else {
            originalValue = false
        }

        defer {
            clearStoredState()
        }

        if try currentSleepDisabledValue() != originalValue {
            try setSleepDisabledValue(originalValue)
        }
        return originalValue
    }

    private func currentSleepDisabledValue() throws -> Bool {
        if let helperController, helperController.isInstalled {
            do {
                return try helperController.readSleepDisabled()
            } catch {
                // Fall back to direct read so a broken helper does not prevent restoring the local setting.
            }
        }

        let result = try commandRunner.run(
            executablePath: "/usr/bin/pmset",
            arguments: ["-g", "live"]
        )

        guard result.exitCode == 0 else {
            throw ClosedLidSleepDisablerError.commandFailed(
                command: "pmset -g live",
                detail: result.failureSummary
            )
        }

        do {
            return try SleepDisabledLiveParser.parse(result.stdout)
        } catch {
            throw ClosedLidSleepDisablerError.unsupported
        }
    }

    private func setSleepDisabledValue(_ isDisabled: Bool) throws {
        if ProcessInfo.processInfo.environment["MACDOG_SKIP_CLOSED_LID_PMSET"] == "1" {
            return
        }

        let invocation = PrivilegedHelperCommandPlanner.pmsetInvocation(for: .setSleepDisabled(isDisabled))
        if let helperController, helperController.isInstalled {
            do {
                try helperController.setSleepDisabled(isDisabled)
                return
            } catch {
                // Preserve the previous AppleScript behavior when the helper is missing, stale, or unhealthy.
            }
        }

        let command = invocation.displayCommand
        let script = "do shell script \(Self.appleScriptLiteral(command)) with administrator privileges"
        let result = try commandRunner.run(
            executablePath: "/usr/bin/osascript",
            arguments: ["-e", script]
        )

        guard result.exitCode == 0 else {
            throw ClosedLidSleepDisablerError.commandFailed(
                command: command,
                detail: result.failureSummary
            )
        }
    }

    private func clearStoredState() {
        defaults.removeObject(forKey: Self.changedByMacDogKey)
        defaults.removeObject(forKey: Self.originalSleepDisabledKey)
    }

    private static func appleScriptLiteral(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}

protocol ClosedLidSleepHelperControlling {
    var isInstalled: Bool { get }
    func readSleepDisabled() throws -> Bool
    func setSleepDisabled(_ isDisabled: Bool) throws
}

struct XPCClosedLidSleepHelperController: ClosedLidSleepHelperControlling {
    private let requestSender: PrivilegedHelperRequestSending
    private let installSnapshotProvider: () -> PrivilegedHelperInstallSnapshot
    private let timeoutSeconds: TimeInterval

    init(
        requestSender: PrivilegedHelperRequestSending = MacDogPrivilegedHelperClient(),
        installSnapshotProvider: @escaping () -> PrivilegedHelperInstallSnapshot = {
            PrivilegedHelperInstallStateReader(
                fileChecker: FileManagerPrivilegedHelperFileChecker()
            ).snapshot()
        },
        timeoutSeconds: TimeInterval = 3
    ) {
        self.requestSender = requestSender
        self.installSnapshotProvider = installSnapshotProvider
        self.timeoutSeconds = timeoutSeconds
    }

    var isInstalled: Bool {
        installSnapshotProvider().status == .installed
    }

    func readSleepDisabled() throws -> Bool {
        let response = try send(.readSleepDisabled)
        guard response.status == .success, let sleepDisabled = response.sleepDisabled else {
            throw ClosedLidSleepHelperError.failed(response.errorMessage ?? response.status.rawValue)
        }
        return sleepDisabled
    }

    func setSleepDisabled(_ isDisabled: Bool) throws {
        let response = try send(.setSleepDisabled(isDisabled))
        guard response.status == .success else {
            throw ClosedLidSleepHelperError.failed(response.errorMessage ?? response.status.rawValue)
        }
    }

    private func send(_ command: PrivilegedHelperCommand) throws -> PrivilegedHelperResponse {
        let semaphore = DispatchSemaphore(value: 0)
        let resultLock = NSLock()
        var result: Result<PrivilegedHelperResponse, Error>?

        requestSender.send(PrivilegedHelperRequest(command: command)) { response in
            resultLock.lock()
            if result == nil {
                result = response
                semaphore.signal()
            }
            resultLock.unlock()
        }

        guard semaphore.wait(timeout: .now() + timeoutSeconds) == .success else {
            throw ClosedLidSleepHelperError.timedOut
        }

        resultLock.lock()
        let completedResult = result
        resultLock.unlock()

        switch completedResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        case nil:
            throw ClosedLidSleepHelperError.unavailable
        }
    }
}

enum ClosedLidSleepHelperError: LocalizedError, Equatable {
    case unavailable
    case timedOut
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "권한 도우미에 연결할 수 없습니다."
        case .timedOut:
            "권한 도우미 응답 시간이 초과되었습니다."
        case .failed(let detail):
            "권한 도우미 실패: \(detail)"
        }
    }
}

enum ClosedLidSleepDisablerError: LocalizedError, Equatable {
    case unsupported
    case commandFailed(command: String, detail: String)

    var errorDescription: String? {
        switch self {
        case .unsupported:
            "덮개 닫힘 방지 설정을 확인할 수 없습니다."
        case .commandFailed(let command, let detail):
            "\(command) 실패: \(detail)"
        }
    }
}

protocol CommandRunning {
    func run(executablePath: String, arguments: [String]) throws -> CommandResult
}

struct CommandResult: Equatable {
    let exitCode: Int32
    let stdout: String
    let stderr: String

    var failureSummary: String {
        let trimmedError = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedError.isEmpty {
            return trimmedError
        }

        let trimmedOutput = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedOutput.isEmpty ? "exit \(exitCode)" : trimmedOutput
    }
}

struct ProcessCommandRunner: CommandRunning {
    func run(executablePath: String, arguments: [String]) throws -> CommandResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return CommandResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)
    }
}
