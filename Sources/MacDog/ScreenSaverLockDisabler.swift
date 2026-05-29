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
    private static let systemScreenLockCommand = "/usr/sbin/sysadminctl"

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

        if let systemDelay = try? readSystemScreenLockDelay(),
           systemDelay.requiresPassword {
            throw ScreenSaverLockDisablerError.systemLockStillEnabled(systemDelay.displayLabel)
        }

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

    private func readSystemScreenLockDelay() throws -> SystemScreenLockDelay {
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
        return SystemScreenLockDelay.parse(output)
    }

    private func clearStoredState() {
        defaults.removeObject(forKey: Self.changedByMacDogKey)
        defaults.removeObject(forKey: Self.originalAskForPasswordExistsKey)
        defaults.removeObject(forKey: Self.originalAskForPasswordKey)
        defaults.removeObject(forKey: Self.originalAskForPasswordDelayExistsKey)
        defaults.removeObject(forKey: Self.originalAskForPasswordDelayKey)
    }
}

private enum SystemScreenLockDelay: Equatable {
    case off
    case immediate
    case seconds(Int)
    case unknown(String)

    var requiresPassword: Bool {
        switch self {
        case .off:
            false
        case .immediate, .seconds, .unknown:
            true
        }
    }

    var displayLabel: String {
        switch self {
        case .off:
            "안 함"
        case .immediate:
            "즉시"
        case .seconds(let seconds):
            "\(seconds)초 후"
        case .unknown(let rawValue):
            rawValue.isEmpty ? "알 수 없음" : rawValue
        }
    }

    static func parse(_ output: String) -> SystemScreenLockDelay {
        let normalized = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = normalized.lowercased()

        if lowercased.contains("off") {
            return .off
        }
        if lowercased.contains("immediate") {
            return .immediate
        }

        let pattern = #"screenlock delay is ([0-9]+)"#
        if let match = lowercased.range(of: pattern, options: .regularExpression) {
            let matched = String(lowercased[match])
            let secondsText = matched
                .split(separator: " ")
                .last
                .map(String.init)
            if let secondsText, let seconds = Int(secondsText) {
                return .seconds(seconds)
            }
        }

        return .unknown(normalized)
    }
}

enum ScreenSaverLockDisablerError: LocalizedError, Equatable {
    case readFailed(key: String)
    case commandFailed(detail: String)
    case systemLockStillEnabled(String)

    var errorDescription: String? {
        switch self {
        case .readFailed(let key):
            "\(key) 잠금 설정을 읽을 수 없습니다."
        case .commandFailed(let detail):
            "화면 잠금 설정 변경 실패: \(detail)"
        case .systemLockStillEnabled(let status):
            "macOS 잠금 화면 설정이 \(status)입니다. 시스템 설정 > 잠금 화면에서 '화면 보호기 또는 디스플레이가 꺼진 후 암호 요구'를 '안 함'으로 바꿔야 로그인창을 막을 수 있습니다."
        }
    }
}
