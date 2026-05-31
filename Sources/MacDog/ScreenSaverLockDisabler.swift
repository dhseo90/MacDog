import Foundation
import MacDogPrivilegedHelperSupport

protocol ScreenLockDisabling {
    @discardableResult
    func setScreenLockDisabled(_ isDisabled: Bool) throws -> Bool
}

struct ScreenSaverLockDisabler: ScreenLockDisabling {
    private static let changedByMacDogKey = "screenLockDisabledByMacDog"
    private static let originalAskForPasswordExistsKey = "screenLockOriginalAskForPasswordExists"
    private static let originalAskForPasswordKey = "screenLockOriginalAskForPassword"
    private static let originalAskForPasswordDelayExistsKey = "screenLockOriginalAskForPasswordDelayExists"
    private static let originalAskForPasswordDelayKey = "screenLockOriginalAskForPasswordDelay"
    private static let originalSystemDelayStoredKey = "screenLockOriginalSystemDelayStored"
    private static let originalSystemDelayNameKey = "screenLockOriginalSystemDelayName"
    private static let originalSystemDelaySecondsKey = "screenLockOriginalSystemDelaySeconds"
    private static let originalSystemDelayRawValueKey = "screenLockOriginalSystemDelayRawValue"
    private static let domain = "com.apple.screensaver"
    private static let systemScreenLockCommand = "/usr/sbin/sysadminctl"

    private let defaults: UserDefaults
    private let commandRunner: CommandRunning
    private let helperController: ScreenLockHelperControlling?

    init(
        defaults: UserDefaults = .standard,
        commandRunner: CommandRunning = ProcessCommandRunner(),
        helperController: ScreenLockHelperControlling? = XPCScreenLockHelperController()
    ) {
        self.defaults = defaults
        self.commandRunner = commandRunner
        self.helperController = helperController
    }

    @discardableResult
    func setScreenLockDisabled(_ isDisabled: Bool) throws -> Bool {
        if isDisabled {
            return try disableScreenLock()
        }
        return try restoreScreenLock()
    }

    private func disableScreenLock() throws -> Bool {
        if !defaults.bool(forKey: Self.changedByMacDogKey) {
            storeOriginalValue(key: "askForPassword", existsKey: Self.originalAskForPasswordExistsKey, valueKey: Self.originalAskForPasswordKey)
            storeOriginalValue(key: "askForPasswordDelay", existsKey: Self.originalAskForPasswordDelayExistsKey, valueKey: Self.originalAskForPasswordDelayKey)
            defaults.set(true, forKey: Self.changedByMacDogKey)
        }

        try storeOriginalSystemDelayIfNeeded()
        try writeCurrentHostInt(key: "askForPassword", value: 0)
        try writeCurrentHostInt(key: "askForPasswordDelay", value: 0)

        if let helperController, helperController.isInstalled {
            try? helperController.setScreenLockDelay(.off)
        }

        return true
    }

    private func restoreScreenLock() throws -> Bool {
        guard defaults.bool(forKey: Self.changedByMacDogKey) else { return false }
        try restoreValue(key: "askForPassword", existsKey: Self.originalAskForPasswordExistsKey, valueKey: Self.originalAskForPasswordKey)
        try restoreValue(key: "askForPasswordDelay", existsKey: Self.originalAskForPasswordDelayExistsKey, valueKey: Self.originalAskForPasswordDelayKey)
        try restoreSystemDelayIfNeeded()
        clearStoredState()
        return false
    }

    private func storeOriginalSystemDelayIfNeeded() throws {
        guard !defaults.bool(forKey: Self.originalSystemDelayStoredKey) else { return }
        guard let helperController, helperController.isInstalled else { return }

        let delay = try helperController.readScreenLockDelay()
        guard delay.sysadminctlArgument != nil else {
            throw ScreenSaverLockDisablerError.unsupportedSystemLockStatus(delay.displayLabel)
        }

        storeSystemDelay(delay)
    }

    private func restoreSystemDelayIfNeeded() throws {
        guard let delay = storedSystemDelay() else { return }
        guard delay.sysadminctlArgument != nil else {
            throw ScreenSaverLockDisablerError.unsupportedSystemLockStatus(delay.displayLabel)
        }
        guard let helperController, helperController.isInstalled else {
            throw ScreenSaverLockDisablerError.helperUnavailableForSystemRestore
        }
        try helperController.setScreenLockDelay(delay)
    }

    private func storeSystemDelay(_ delay: ScreenLockDelay) {
        defaults.set(true, forKey: Self.originalSystemDelayStoredKey)

        switch delay {
        case .off:
            defaults.set("off", forKey: Self.originalSystemDelayNameKey)
            defaults.removeObject(forKey: Self.originalSystemDelaySecondsKey)
            defaults.removeObject(forKey: Self.originalSystemDelayRawValueKey)
        case .immediate:
            defaults.set("immediate", forKey: Self.originalSystemDelayNameKey)
            defaults.removeObject(forKey: Self.originalSystemDelaySecondsKey)
            defaults.removeObject(forKey: Self.originalSystemDelayRawValueKey)
        case .seconds(let seconds):
            defaults.set("seconds", forKey: Self.originalSystemDelayNameKey)
            defaults.set(seconds, forKey: Self.originalSystemDelaySecondsKey)
            defaults.removeObject(forKey: Self.originalSystemDelayRawValueKey)
        case .unknown(let rawValue):
            defaults.set("unknown", forKey: Self.originalSystemDelayNameKey)
            defaults.removeObject(forKey: Self.originalSystemDelaySecondsKey)
            defaults.set(rawValue, forKey: Self.originalSystemDelayRawValueKey)
        }
    }

    private func storedSystemDelay() -> ScreenLockDelay? {
        guard defaults.bool(forKey: Self.originalSystemDelayStoredKey) else { return nil }

        switch defaults.string(forKey: Self.originalSystemDelayNameKey) {
        case "off":
            return .off
        case "immediate":
            return .immediate
        case "seconds":
            return .seconds(defaults.integer(forKey: Self.originalSystemDelaySecondsKey))
        case "unknown":
            return .unknown(defaults.string(forKey: Self.originalSystemDelayRawValueKey) ?? "")
        default:
            return nil
        }
    }

    private func storeOriginalValue(key: String, existsKey: String, valueKey: String) {
        if let value = try? readCurrentHostInt(key: key) {
            defaults.set(true, forKey: existsKey)
            defaults.set(value, forKey: valueKey)
        } else {
            defaults.set(false, forKey: existsKey)
            defaults.removeObject(forKey: valueKey)
        }
    }

    private func restoreValue(key: String, existsKey: String, valueKey: String) throws {
        if defaults.bool(forKey: existsKey) {
            try writeCurrentHostInt(key: key, value: defaults.integer(forKey: valueKey))
        } else {
            try deleteCurrentHostValue(key: key)
        }
    }

    private func readCurrentHostInt(key: String) throws -> Int {
        let result = try commandRunner.run(
            executablePath: "/usr/bin/defaults",
            arguments: ["-currentHost", "read", Self.domain, key]
        )
        guard result.exitCode == 0,
              let value = Int(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw ScreenSaverLockDisablerError.readFailed(key: key)
        }
        return value
    }

    private func writeCurrentHostInt(key: String, value: Int) throws {
        let result = try commandRunner.run(
            executablePath: "/usr/bin/defaults",
            arguments: ["-currentHost", "write", Self.domain, key, "-int", String(value)]
        )
        guard result.exitCode == 0 else {
            throw ScreenSaverLockDisablerError.commandFailed(detail: result.failureSummary)
        }
    }

    private func deleteCurrentHostValue(key: String) throws {
        let result = try commandRunner.run(
            executablePath: "/usr/bin/defaults",
            arguments: ["-currentHost", "delete", Self.domain, key]
        )
        guard result.exitCode == 0 || result.failureSummary.contains("does not exist") else {
            throw ScreenSaverLockDisablerError.commandFailed(detail: result.failureSummary)
        }
    }

    private func readSystemScreenLockDelay() throws -> ScreenLockDelay {
        let result = try commandRunner.run(
            executablePath: Self.systemScreenLockCommand,
            arguments: ["-screenLock", "status"]
        )
        guard result.exitCode == 0 else {
            throw ScreenSaverLockDisablerError.commandFailed(detail: result.failureSummary)
        }

        let output = [result.stdout, result.stderr]
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return ScreenLockDelayParser.parse(output)
    }

    private func clearStoredState() {
        defaults.removeObject(forKey: Self.changedByMacDogKey)
        defaults.removeObject(forKey: Self.originalAskForPasswordExistsKey)
        defaults.removeObject(forKey: Self.originalAskForPasswordKey)
        defaults.removeObject(forKey: Self.originalAskForPasswordDelayExistsKey)
        defaults.removeObject(forKey: Self.originalAskForPasswordDelayKey)
        defaults.removeObject(forKey: Self.originalSystemDelayStoredKey)
        defaults.removeObject(forKey: Self.originalSystemDelayNameKey)
        defaults.removeObject(forKey: Self.originalSystemDelaySecondsKey)
        defaults.removeObject(forKey: Self.originalSystemDelayRawValueKey)
    }
}

protocol ScreenLockHelperControlling {
    var isInstalled: Bool { get }
    func readScreenLockDelay() throws -> ScreenLockDelay
    func setScreenLockDelay(_ delay: ScreenLockDelay) throws
}

struct XPCScreenLockHelperController: ScreenLockHelperControlling {
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

    func readScreenLockDelay() throws -> ScreenLockDelay {
        let response = try send(.readScreenLockDelay)
        guard response.status == .success, let delay = response.screenLockDelay else {
            throw ScreenLockHelperError.failed(response.errorMessage ?? response.status.rawValue)
        }
        return delay
    }

    func setScreenLockDelay(_ delay: ScreenLockDelay) throws {
        let response = try send(.setScreenLockDelay(delay))
        guard response.status == .success else {
            throw ScreenLockHelperError.failed(response.errorMessage ?? response.status.rawValue)
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
            throw ScreenLockHelperError.timedOut
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
            throw ScreenLockHelperError.unavailable
        }
    }
}

enum ScreenLockHelperError: LocalizedError, Equatable {
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

enum ScreenSaverLockDisablerError: LocalizedError, Equatable {
    case readFailed(key: String)
    case commandFailed(detail: String)
    case systemLockStillEnabled(String)
    case unsupportedSystemLockStatus(String)
    case helperUnavailableForSystemRestore

    var errorDescription: String? {
        switch self {
        case .readFailed(let key):
            "\(key) 잠금 설정을 읽을 수 없습니다."
        case .commandFailed(let detail):
            "화면 잠금 설정 변경 실패: \(detail)"
        case .systemLockStillEnabled(let status):
            "macOS 잠금 화면 설정이 \(status)입니다. 시스템 설정 > 잠금 화면에서 '화면 보호기 또는 디스플레이가 꺼진 후 암호 요구'를 '안 함'으로 바꿔야 로그인창을 막을 수 있습니다."
        case .unsupportedSystemLockStatus(let status):
            "macOS 잠금 화면 설정 값이 지원 범위를 벗어났습니다: \(status)"
        case .helperUnavailableForSystemRestore:
            "권한 도우미가 없어 macOS 잠금 화면 설정을 원래 상태로 복원할 수 없습니다."
        }
    }
}
