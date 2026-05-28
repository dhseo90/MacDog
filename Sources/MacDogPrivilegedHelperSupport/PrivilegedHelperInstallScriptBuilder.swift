import Foundation

public struct PrivilegedHelperInstallScriptBuilder: Equatable, Sendable {
    public let plan: PrivilegedHelperInstallPlan
    public let logDirectory: String

    public init(
        plan: PrivilegedHelperInstallPlan = .current,
        logDirectory: String = "/Library/Logs/MacDog"
    ) {
        self.plan = plan
        self.logDirectory = logDirectory
    }

    public func launchDaemonPlist(
        hostTeamIdentifier: String?,
        allowAdHocHost: Bool
    ) -> String {
        var environmentEntries = ""
        if let hostTeamIdentifier, !hostTeamIdentifier.isEmpty {
            environmentEntries += """

                <key>MACDOG_HELPER_HOST_TEAM_ID</key>
                <string>\(Self.xmlEscaped(hostTeamIdentifier))</string>
            """
        }
        if allowAdHocHost {
            environmentEntries += """

                <key>MACDOG_HELPER_ALLOW_ADHOC_HOST</key>
                <string>1</string>
            """
        }

        let environmentBlock = environmentEntries.isEmpty ? "" : """

              <key>EnvironmentVariables</key>
              <dict>\(environmentEntries)
              </dict>
        """

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>Label</key>
          <string>\(Self.xmlEscaped(plan.label))</string>
          <key>ProgramArguments</key>
          <array>
            <string>\(Self.xmlEscaped(plan.helperToolDestination))</string>
            <string>--run-xpc-service</string>
          </array>
          <key>MachServices</key>
          <dict>
            <key>\(Self.xmlEscaped(plan.machServiceName))</key>
            <true/>
          </dict>\(environmentBlock)
          <key>RunAtLoad</key>
          <true/>
          <key>StandardOutPath</key>
          <string>\(Self.xmlEscaped(logDirectory))/helper.out.log</string>
          <key>StandardErrorPath</key>
          <string>\(Self.xmlEscaped(logDirectory))/helper.err.log</string>
        </dict>
        </plist>
        """
    }

    public func installRootScript(
        helperSourcePath: String,
        launchDaemonPlistSourcePath: String
    ) -> String {
        """
        #!/usr/bin/env bash
        set -euo pipefail
        /bin/launchctl bootout system \(Self.shellQuoted(plan.launchDaemonDestination)) >/dev/null 2>&1 || true
        /bin/mkdir -p /Library/PrivilegedHelperTools /Library/LaunchDaemons \(Self.shellQuoted(logDirectory))
        /usr/bin/install -o root -g wheel -m 755 \(Self.shellQuoted(helperSourcePath)) \(Self.shellQuoted(plan.helperToolDestination))
        /usr/bin/install -o root -g wheel -m 644 \(Self.shellQuoted(launchDaemonPlistSourcePath)) \(Self.shellQuoted(plan.launchDaemonDestination))
        /bin/launchctl bootstrap system \(Self.shellQuoted(plan.launchDaemonDestination))
        /bin/launchctl print \(Self.shellQuoted("system/\(plan.label)")) >/dev/null
        /usr/bin/codesign --verify --strict --verbose=2 \(Self.shellQuoted(plan.helperToolDestination)) >/dev/null
        """
    }

    public func uninstallRootScript() -> String {
        """
        #!/usr/bin/env bash
        set -euo pipefail
        /bin/launchctl bootout system \(Self.shellQuoted(plan.launchDaemonDestination)) >/dev/null 2>&1 || true
        /bin/rm -f \(Self.shellQuoted(plan.helperToolDestination)) \(Self.shellQuoted(plan.launchDaemonDestination))
        """
    }

    public static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    public static func appleScriptLiteral(_ value: String) -> String {
        "\"" + value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    private static func xmlEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
