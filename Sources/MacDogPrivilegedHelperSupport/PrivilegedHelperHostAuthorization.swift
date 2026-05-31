import Foundation
import Security

public struct PrivilegedHelperHostRequirement: Equatable, Sendable {
    public let bundleIdentifier: String
    public let teamIdentifier: String?
    public let acceptsAdHocDevelopmentSignature: Bool
    public let explicitRequirementString: String?

    public init(
        bundleIdentifier: String = MacDogPrivilegedHelperContract.hostBundleIdentifier,
        teamIdentifier: String? = nil,
        acceptsAdHocDevelopmentSignature: Bool = false,
        explicitRequirementString: String? = nil
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.teamIdentifier = teamIdentifier
        self.acceptsAdHocDevelopmentSignature = acceptsAdHocDevelopmentSignature
        self.explicitRequirementString = explicitRequirementString
    }

    public static func runtime(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> PrivilegedHelperHostRequirement {
        PrivilegedHelperHostRequirement(
            teamIdentifier: environment["MACDOG_HELPER_HOST_TEAM_ID"],
            acceptsAdHocDevelopmentSignature: false,
            explicitRequirementString: environment["MACDOG_HELPER_HOST_REQUIREMENT"]
        )
    }

    public var requirementString: String {
        if let explicitRequirementString,
           !explicitRequirementString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return explicitRequirementString
        }

        var terms = ["identifier \(Self.quoted(bundleIdentifier))"]

        if let teamIdentifier, !teamIdentifier.isEmpty {
            terms.append("anchor apple generic")
            terms.append("certificate leaf[subject.OU] = \(Self.quoted(teamIdentifier))")
        } else {
            terms.append("anchor apple generic")
        }

        return terms.joined(separator: " and ")
    }

    private static func quoted(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}

public protocol PrivilegedHelperConnectionAuthorizing {
    func shouldAccept(processIdentifier: pid_t) -> Bool
}

public struct SecCodePrivilegedHelperConnectionAuthorizer: PrivilegedHelperConnectionAuthorizing, Sendable {
    public let requirement: PrivilegedHelperHostRequirement

    public init(requirement: PrivilegedHelperHostRequirement = .runtime()) {
        self.requirement = requirement
    }

    public func shouldAccept(processIdentifier: pid_t) -> Bool {
        guard processIdentifier > 0 else { return false }

        var code: SecCode?
        let attributes = [
            kSecGuestAttributePid as String: NSNumber(value: processIdentifier)
        ] as CFDictionary

        guard SecCodeCopyGuestWithAttributes(nil, attributes, SecCSFlags(), &code) == errSecSuccess,
              let code else {
            return false
        }

        var requirementRef: SecRequirement?
        guard SecRequirementCreateWithString(
            requirement.requirementString as CFString,
            SecCSFlags(),
            &requirementRef
        ) == errSecSuccess, let requirementRef else {
            return false
        }

        return SecCodeCheckValidity(code, SecCSFlags(), requirementRef) == errSecSuccess
    }
}
