import Foundation
import MacDogPrivilegedHelperSupport

struct PrivilegedHelperInstaller: Sendable {
    let plan: PrivilegedHelperInstallPlan
    let scriptBuilder: PrivilegedHelperInstallScriptBuilder

    init(
        plan: PrivilegedHelperInstallPlan = .current,
        scriptBuilder: PrivilegedHelperInstallScriptBuilder = PrivilegedHelperInstallScriptBuilder()
    ) {
        self.plan = plan
        self.scriptBuilder = scriptBuilder
    }

    func install(appBundleURL: URL = Bundle.main.bundleURL) throws {
        let helperURL = appBundleURL.appendingPathComponent(plan.embeddedHelperRelativePath)
        guard FileManager.default.isExecutableFile(atPath: helperURL.path) else {
            throw PrivilegedHelperInstallerError.missingEmbeddedHelper(helperURL.path)
        }

        try runProcess("/usr/bin/codesign", arguments: [
            "--verify",
            "--strict",
            "--verbose=2",
            helperURL.path
        ])

        let hostTeamIdentifier = try detectHostTeamIdentifier(appBundleURL: appBundleURL)
        let allowAdHocHost = hostTeamIdentifier == nil
        let tempPlistURL = try writeTemporaryFile(
            prefix: "macdog-helper",
            contents: scriptBuilder.launchDaemonPlist(
                hostTeamIdentifier: hostTeamIdentifier,
                allowAdHocHost: allowAdHocHost
            )
        )
        let rootScriptURL = try writeTemporaryFile(
            prefix: "macdog-helper-install",
            contents: scriptBuilder.installRootScript(
                helperSourcePath: helperURL.path,
                launchDaemonPlistSourcePath: tempPlistURL.path
            )
        )
        defer {
            try? FileManager.default.removeItem(at: tempPlistURL)
            try? FileManager.default.removeItem(at: rootScriptURL)
        }

        try runProcess("/usr/bin/plutil", arguments: ["-lint", tempPlistURL.path])
        try runWithAdministratorApproval(rootScriptURL)
    }

    func uninstall() throws {
        let rootScriptURL = try writeTemporaryFile(
            prefix: "macdog-helper-uninstall",
            contents: scriptBuilder.uninstallRootScript()
        )
        defer {
            try? FileManager.default.removeItem(at: rootScriptURL)
        }

        try runWithAdministratorApproval(rootScriptURL)
    }

    private func detectHostTeamIdentifier(appBundleURL: URL) throws -> String? {
        let output = try runProcess("/usr/bin/codesign", arguments: [
            "-dv",
            "--verbose=4",
            appBundleURL.path
        ], allowedExitCodes: [0])

        for line in output.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("TeamIdentifier=") else { continue }
            let value = String(trimmed.dropFirst("TeamIdentifier=".count))
            return value == "not set" || value.isEmpty ? nil : value
        }

        return nil
    }

    private func runWithAdministratorApproval(_ scriptURL: URL) throws {
        let command = PrivilegedHelperInstallScriptBuilder.shellQuoted(scriptURL.path)
        let appleScript = "do shell script \(PrivilegedHelperInstallScriptBuilder.appleScriptLiteral(command)) with administrator privileges"
        var errorInfo: NSDictionary?
        let result = NSAppleScript(source: appleScript)?.executeAndReturnError(&errorInfo)
        if result == nil, let errorInfo {
            throw PrivilegedHelperInstallerError.appleScriptFailed(
                message: errorInfo[NSAppleScript.errorMessage] as? String,
                number: errorInfo[NSAppleScript.errorNumber] as? Int
            )
        }
    }

    private func writeTemporaryFile(prefix: String, contents: String) throws -> URL {
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let url = tempDirectory.appendingPathComponent("\(prefix).\(UUID().uuidString)")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        return url
    }

    @discardableResult
    private func runProcess(
        _ executablePath: String,
        arguments: [String],
        allowedExitCodes: Set<Int32> = [0]
    ) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard allowedExitCodes.contains(process.terminationStatus) else {
            throw PrivilegedHelperInstallerError.commandFailed(
                executablePath,
                process.terminationStatus,
                (output + error).trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        return output + error
    }
}

enum PrivilegedHelperInstallerError: LocalizedError {
    case missingEmbeddedHelper(String)
    case commandFailed(String, Int32, String)
    case appleScriptFailed(message: String?, number: Int?)

    var errorDescription: String? {
        switch self {
        case .missingEmbeddedHelper(let path):
            return "권한 도우미 실행 파일을 찾을 수 없습니다: \(path)"
        case .commandFailed(let command, let status, let detail):
            if detail.isEmpty {
                return "권한 도우미 명령 실패: \(command) (\(status))"
            }
            return "권한 도우미 명령 실패: \(command) (\(status)) · \(detail)"
        case .appleScriptFailed(let message, let number):
            if let message, let number {
                return "권한 도우미 관리자 승인 실패: \(message) (\(number))"
            }
            if let message {
                return "권한 도우미 관리자 승인 실패: \(message)"
            }
            return "권한 도우미 관리자 승인 실패"
        }
    }
}
