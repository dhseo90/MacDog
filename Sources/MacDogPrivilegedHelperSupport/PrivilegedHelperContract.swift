import Foundation

public enum MacDogPrivilegedHelperContract {
    public static let hostBundleIdentifier = "com.dhseo.macdog.MacDog"
    public static let label = "com.dhseo.macdog.helper"
    public static let machServiceName = "com.dhseo.macdog.helper.xpc"
    public static let executableName = "MacDogPrivilegedHelper"
    public static let launchDaemonPlistName = "\(label).plist"
    public static let embeddedHelperRelativePath = "Contents/Library/LaunchServices/\(executableName)"
    public static let embeddedLaunchDaemonRelativePath = "Contents/Library/LaunchDaemons/\(launchDaemonPlistName)"
    public static let helperToolDestination = "/Library/PrivilegedHelperTools/\(label)"
    public static let launchDaemonDestination = "/Library/LaunchDaemons/\(launchDaemonPlistName)"
    public static let protocolVersion = 1
    public static let helperVersion = "helper-contract-1"
}

public struct PrivilegedHelperRequest: Codable, Equatable, Sendable {
    public let protocolVersion: Int
    public let command: PrivilegedHelperCommand

    public init(
        protocolVersion: Int = MacDogPrivilegedHelperContract.protocolVersion,
        command: PrivilegedHelperCommand
    ) {
        self.protocolVersion = protocolVersion
        self.command = command
    }
}

public enum PrivilegedHelperCommand: Codable, Equatable, Sendable {
    case readSleepDisabled
    case setSleepDisabled(Bool)
    case readScreenLockDelay
    case setScreenLockDelay(ScreenLockDelay)

    private enum CodingKeys: String, CodingKey {
        case name
        case sleepDisabled
        case screenLockDelay
    }

    private enum Name: String, Codable {
        case readSleepDisabled
        case setSleepDisabled
        case readScreenLockDelay
        case setScreenLockDelay
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(Name.self, forKey: .name)

        switch name {
        case .readSleepDisabled:
            self = .readSleepDisabled
        case .setSleepDisabled:
            self = .setSleepDisabled(try container.decode(Bool.self, forKey: .sleepDisabled))
        case .readScreenLockDelay:
            self = .readScreenLockDelay
        case .setScreenLockDelay:
            self = .setScreenLockDelay(try container.decode(ScreenLockDelay.self, forKey: .screenLockDelay))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .readSleepDisabled:
            try container.encode(Name.readSleepDisabled, forKey: .name)
        case .setSleepDisabled(let sleepDisabled):
            try container.encode(Name.setSleepDisabled, forKey: .name)
            try container.encode(sleepDisabled, forKey: .sleepDisabled)
        case .readScreenLockDelay:
            try container.encode(Name.readScreenLockDelay, forKey: .name)
        case .setScreenLockDelay(let screenLockDelay):
            try container.encode(Name.setScreenLockDelay, forKey: .name)
            try container.encode(screenLockDelay, forKey: .screenLockDelay)
        }
    }
}

public enum ScreenLockDelay: Codable, Equatable, Sendable {
    case off
    case immediate
    case seconds(Int)
    case unknown(String)

    private enum CodingKeys: String, CodingKey {
        case name
        case seconds
        case rawValue
    }

    private enum Name: String, Codable {
        case off
        case immediate
        case seconds
        case unknown
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(Name.self, forKey: .name)

        switch name {
        case .off:
            self = .off
        case .immediate:
            self = .immediate
        case .seconds:
            self = .seconds(try container.decode(Int.self, forKey: .seconds))
        case .unknown:
            self = .unknown(try container.decode(String.self, forKey: .rawValue))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .off:
            try container.encode(Name.off, forKey: .name)
        case .immediate:
            try container.encode(Name.immediate, forKey: .name)
        case .seconds(let seconds):
            try container.encode(Name.seconds, forKey: .name)
            try container.encode(seconds, forKey: .seconds)
        case .unknown(let rawValue):
            try container.encode(Name.unknown, forKey: .name)
            try container.encode(rawValue, forKey: .rawValue)
        }
    }

    public var requiresPassword: Bool {
        switch self {
        case .off:
            false
        case .immediate, .seconds, .unknown:
            true
        }
    }

    public var displayLabel: String {
        switch self {
        case .off:
            "안 함"
        case .immediate:
            "즉시"
        case .seconds(let seconds):
            "\(seconds)초 후"
        case .unknown(let rawValue):
            rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "알 수 없음" : rawValue
        }
    }

    public var sysadminctlArgument: String? {
        switch self {
        case .off:
            "off"
        case .immediate:
            "immediate"
        case .seconds(let seconds) where seconds >= 0:
            String(seconds)
        case .seconds:
            nil
        case .unknown:
            nil
        }
    }
}

public struct PrivilegedHelperResponse: Codable, Equatable, Sendable {
    public let protocolVersion: Int
    public let helperVersion: String
    public let status: PrivilegedHelperResponseStatus
    public let sleepDisabled: Bool?
    public let screenLockDelay: ScreenLockDelay?
    public let errorMessage: String?

    public init(
        protocolVersion: Int = MacDogPrivilegedHelperContract.protocolVersion,
        helperVersion: String = MacDogPrivilegedHelperContract.helperVersion,
        status: PrivilegedHelperResponseStatus,
        sleepDisabled: Bool? = nil,
        screenLockDelay: ScreenLockDelay? = nil,
        errorMessage: String? = nil
    ) {
        self.protocolVersion = protocolVersion
        self.helperVersion = helperVersion
        self.status = status
        self.sleepDisabled = sleepDisabled
        self.screenLockDelay = screenLockDelay
        self.errorMessage = errorMessage
    }
}

public enum PrivilegedHelperResponseStatus: String, Codable, Equatable, Sendable {
    case success
    case denied
    case failed
    case unsupportedProtocol
    case unsupportedCommand
}

public struct PMSetInvocation: Equatable, Sendable {
    public let executablePath: String
    public let arguments: [String]
    public let displayCommand: String

    public init(executablePath: String, arguments: [String]) {
        self.executablePath = executablePath
        self.arguments = arguments
        self.displayCommand = ([executablePath] + arguments).joined(separator: " ")
    }
}

public enum PrivilegedHelperCommandPlanner {
    public static func pmsetInvocation(for command: PrivilegedHelperCommand) -> PMSetInvocation {
        switch command {
        case .readSleepDisabled:
            PMSetInvocation(executablePath: "/usr/bin/pmset", arguments: ["-g", "live"])
        case .setSleepDisabled(let sleepDisabled):
            PMSetInvocation(
                executablePath: "/usr/bin/pmset",
                arguments: ["-a", "disablesleep", sleepDisabled ? "1" : "0"]
            )
        case .readScreenLockDelay, .setScreenLockDelay:
            preconditionFailure("screenLock commands must use sysadminctlInvocation(for:)")
        }
    }

    public static func sysadminctlInvocation(for command: PrivilegedHelperCommand) -> PMSetInvocation? {
        switch command {
        case .readScreenLockDelay:
            return PMSetInvocation(executablePath: "/usr/sbin/sysadminctl", arguments: ["-screenLock", "status"])
        case .setScreenLockDelay(let delay):
            guard let argument = delay.sysadminctlArgument else { return nil }
            return PMSetInvocation(executablePath: "/usr/sbin/sysadminctl", arguments: ["-screenLock", argument])
        case .readSleepDisabled, .setSleepDisabled:
            return nil
        }
    }
}

public enum SleepDisabledLiveParser {
    public static func parse(_ stdout: String) throws -> Bool {
        for line in stdout.split(whereSeparator: \.isNewline) {
            let parts = line.split(whereSeparator: \.isWhitespace)
            guard parts.first == "SleepDisabled", let rawValue = parts.dropFirst().first else {
                continue
            }

            switch rawValue {
            case "0":
                return false
            case "1":
                return true
            default:
                throw PrivilegedHelperContractError.invalidSleepDisabledValue(String(rawValue))
            }
        }

        throw PrivilegedHelperContractError.missingSleepDisabledValue
    }
}

public enum ScreenLockDelayParser {
    public static func parse(_ output: String) -> ScreenLockDelay {
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

public struct PrivilegedHelperInstallPlan: Equatable, Sendable {
    public let label: String
    public let machServiceName: String
    public let executableName: String
    public let embeddedHelperRelativePath: String
    public let embeddedLaunchDaemonRelativePath: String
    public let helperToolDestination: String
    public let launchDaemonDestination: String
    public let protocolVersion: Int
    public let helperVersion: String

    public static let current = PrivilegedHelperInstallPlan(
        label: MacDogPrivilegedHelperContract.label,
        machServiceName: MacDogPrivilegedHelperContract.machServiceName,
        executableName: MacDogPrivilegedHelperContract.executableName,
        embeddedHelperRelativePath: MacDogPrivilegedHelperContract.embeddedHelperRelativePath,
        embeddedLaunchDaemonRelativePath: MacDogPrivilegedHelperContract.embeddedLaunchDaemonRelativePath,
        helperToolDestination: MacDogPrivilegedHelperContract.helperToolDestination,
        launchDaemonDestination: MacDogPrivilegedHelperContract.launchDaemonDestination,
        protocolVersion: MacDogPrivilegedHelperContract.protocolVersion,
        helperVersion: MacDogPrivilegedHelperContract.helperVersion
    )

    public func dryRunLines(appBundlePath: String) -> [String] {
        [
            "Privileged helper: opt-in",
            "Helper label: \(label)",
            "Helper executable: \(appBundlePath)/\(embeddedHelperRelativePath)",
            "Helper launch daemon plist: \(appBundlePath)/\(embeddedLaunchDaemonRelativePath)",
            "Helper tool destination: \(helperToolDestination)",
            "Helper launch daemon destination: \(launchDaemonDestination)",
            "Helper mach service: \(machServiceName)",
            "Helper protocol: \(protocolVersion)",
            "Helper version: \(helperVersion)",
            "Helper commands: read SleepDisabled, set SleepDisabled 0/1, read screenLock, set screenLock off/immediate/seconds only"
        ]
    }
}

public enum PrivilegedHelperContractError: LocalizedError, Equatable, Sendable {
    case missingSleepDisabledValue
    case invalidSleepDisabledValue(String)

    public var errorDescription: String? {
        switch self {
        case .missingSleepDisabledValue:
            "SleepDisabled 값을 찾을 수 없습니다."
        case .invalidSleepDisabledValue(let value):
            "지원하지 않는 SleepDisabled 값입니다: \(value)"
        }
    }
}
