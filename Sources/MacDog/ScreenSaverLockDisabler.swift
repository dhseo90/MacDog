import Foundation

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
    private static let domain = "com.apple.screensaver"

    private let defaults: UserDefaults
    private let commandRunner: CommandRunning

    init(defaults: UserDefaults = .standard, commandRunner: CommandRunning = ProcessCommandRunner()) {
        self.defaults = defaults
        self.commandRunner = commandRunner
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

        try writeCurrentHostInt(key: "askForPassword", value: 0)
        try writeCurrentHostInt(key: "askForPasswordDelay", value: 0)
        return true
    }

    private func restoreScreenLock() throws -> Bool {
        guard defaults.bool(forKey: Self.changedByMacDogKey) else { return false }
        try restoreValue(key: "askForPassword", existsKey: Self.originalAskForPasswordExistsKey, valueKey: Self.originalAskForPasswordKey)
        try restoreValue(key: "askForPasswordDelay", existsKey: Self.originalAskForPasswordDelayExistsKey, valueKey: Self.originalAskForPasswordDelayKey)
        clearStoredState()
        return false
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

    private func clearStoredState() {
        defaults.removeObject(forKey: Self.changedByMacDogKey)
        defaults.removeObject(forKey: Self.originalAskForPasswordExistsKey)
        defaults.removeObject(forKey: Self.originalAskForPasswordKey)
        defaults.removeObject(forKey: Self.originalAskForPasswordDelayExistsKey)
        defaults.removeObject(forKey: Self.originalAskForPasswordDelayKey)
    }
}

enum ScreenSaverLockDisablerError: LocalizedError, Equatable {
    case readFailed(key: String)
    case commandFailed(detail: String)

    var errorDescription: String? {
        switch self {
        case .readFailed(let key):
            "\(key) 잠금 설정을 읽을 수 없습니다."
        case .commandFailed(let detail):
            "화면 잠금 설정 변경 실패: \(detail)"
        }
    }
}
