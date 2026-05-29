import CodexUsageCore
import Darwin
import Foundation

struct UserComponentInstaller {
    static let cacheLabel = "com.dhseo.macdog.usage-cache"
    static let firstRunHelperPromptDismissedKey = "firstRunHelperPromptDismissed"

    private let appBundleURL: URL
    private let homeDirectory: URL
    private let fileManager: FileManager

    init(
        appBundleURL: URL = Bundle.main.bundleURL,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default
    ) {
        self.appBundleURL = appBundleURL.standardizedFileURL
        self.homeDirectory = homeDirectory
        self.fileManager = fileManager
    }

    static func shouldManage(appBundleURL: URL = Bundle.main.bundleURL, homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> Bool {
        let path = appBundleURL.standardizedFileURL.path
        let userApplicationsPath = homeDirectory
            .appendingPathComponent("Applications", isDirectory: true)
            .appendingPathComponent("MacDog.app", isDirectory: true)
            .standardizedFileURL
            .path
        return path == "/Applications/MacDog.app" || path == userApplicationsPath
    }

    func installOrRepair(loginLaunchEnabled: Bool) throws {
        guard Self.shouldManage(appBundleURL: appBundleURL, homeDirectory: homeDirectory) else { return }
        guard fileManager.isExecutableFile(atPath: bundledCLIURL.path) else {
            throw UserComponentInstallerError.missingBundledCLI(bundledCLIURL.path)
        }

        try fileManager.createDirectory(at: binDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: launchAgentDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: logDirectoryURL, withIntermediateDirectories: true)

        try installCLISymlink()
        try installCacheLaunchAgentIfNeeded()
        try installLoginLaunchIfNeeded(isEnabled: loginLaunchEnabled)
    }

    static func cachePlistData(appCLIPath: String, logDirectoryPath: String) throws -> Data {
        let plist: [String: Any] = [
            "Label": cacheLabel,
            "ProgramArguments": [
                appCLIPath,
                "status",
                "--write-cache",
                "--timeout",
                String(Int(CodexUsageCacheRefreshPolicy.requestTimeout)),
                "--watch",
                String(CodexUsageCacheStore.cacheAgentRefreshIntervalSeconds)
            ],
            "RunAtLoad": true,
            "KeepAlive": true,
            "StandardOutPath": "\(logDirectoryPath)/cache.out.log",
            "StandardErrorPath": "\(logDirectoryPath)/cache.err.log"
        ]
        return try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    }

    private var bundledCLIURL: URL {
        appBundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("MacOS", isDirectory: true)
            .appendingPathComponent("codex-usage")
    }

    private var binDirectoryURL: URL {
        homeDirectory.appendingPathComponent("bin", isDirectory: true)
    }

    private var cliSymlinkURL: URL {
        binDirectoryURL.appendingPathComponent("codex-usage")
    }

    private var launchAgentDirectoryURL: URL {
        homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
    }

    private var cachePlistURL: URL {
        launchAgentDirectoryURL.appendingPathComponent("\(Self.cacheLabel).plist")
    }

    private var logDirectoryURL: URL {
        homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("MacDog", isDirectory: true)
    }

    private var guiTarget: String {
        "gui/\(getuid())"
    }

    private func installCLISymlink() throws {
        if fileManager.fileExists(atPath: cliSymlinkURL.path) {
            try fileManager.removeItem(at: cliSymlinkURL)
        }
        try fileManager.createSymbolicLink(at: cliSymlinkURL, withDestinationURL: bundledCLIURL)
    }

    private func installCacheLaunchAgentIfNeeded() throws {
        let plistData = try Self.cachePlistData(
            appCLIPath: bundledCLIURL.path,
            logDirectoryPath: logDirectoryURL.path
        )
        let existingData = try? Data(contentsOf: cachePlistURL)
        guard existingData != plistData else {
            _ = try? launchctl(arguments: ["bootstrap", guiTarget, cachePlistURL.path])
            return
        }

        _ = try? launchctl(arguments: ["bootout", guiTarget, cachePlistURL.path])
        try plistData.write(to: cachePlistURL, options: .atomic)
        try launchctl(arguments: ["bootstrap", guiTarget, cachePlistURL.path])
    }

    private func installLoginLaunchIfNeeded(isEnabled: Bool) throws {
        let controller = LoginLaunchController(
            appBundleURL: appBundleURL,
            homeDirectory: homeDirectory,
            fileManager: fileManager
        )

        if isEnabled {
            try controller.setEnabled(true)
        } else {
            try controller.setEnabled(false)
        }
    }

    @discardableResult
    private func launchctl(arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw UserComponentInstallerError.launchctlFailed(arguments.joined(separator: " "), (output + error).trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return output + error
    }
}

enum UserComponentInstallerError: LocalizedError, Equatable {
    case missingBundledCLI(String)
    case launchctlFailed(String, String)

    var errorDescription: String? {
        switch self {
        case .missingBundledCLI(let path):
            return "번들 내부 codex-usage 실행 파일을 찾을 수 없습니다: \(path)"
        case .launchctlFailed(let command, let detail):
            if detail.isEmpty {
                return "사용자 자동 실행 설정 실패: launchctl \(command)"
            }
            return "사용자 자동 실행 설정 실패: launchctl \(command) · \(detail)"
        }
    }
}
