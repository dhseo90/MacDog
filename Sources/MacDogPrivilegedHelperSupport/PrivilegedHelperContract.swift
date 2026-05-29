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
    public static let helperVersion = "1.0.0"
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

    private enum CodingKeys: String, CodingKey {
        case name
        case sleepDisabled
    }

    private enum Name: String, Codable {
        case readSleepDisabled
        case setSleepDisabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(Name.self, forKey: .name)

        switch name {
        case .readSleepDisabled:
            self = .readSleepDisabled
        case .setSleepDisabled:
            self = .setSleepDisabled(try container.decode(Bool.self, forKey: .sleepDisabled))
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
        }
    }
}

public struct PrivilegedHelperResponse: Codable, Equatable, Sendable {
    public let protocolVersion: Int
    public let helperVersion: String
    public let status: PrivilegedHelperResponseStatus
    public let sleepDisabled: Bool?
    public let errorMessage: String?

    public init(
        protocolVersion: Int = MacDogPrivilegedHelperContract.protocolVersion,
        helperVersion: String = MacDogPrivilegedHelperContract.helperVersion,
        status: PrivilegedHelperResponseStatus,
        sleepDisabled: Bool? = nil,
        errorMessage: String? = nil
    ) {
        self.protocolVersion = protocolVersion
        self.helperVersion = helperVersion
        self.status = status
        self.sleepDisabled = sleepDisabled
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
            "Helper commands: read SleepDisabled, set SleepDisabled 0/1 only"
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
