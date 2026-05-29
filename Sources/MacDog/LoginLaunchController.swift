import Darwin
import Foundation

struct LoginLaunchController {
    static let label = "com.dhseo.macdog.monitor"

    private let appBundleURL: URL
    private let homeDirectory: URL
    private let fileManager: FileManager

    init(
        appBundleURL: URL = Bundle.main.bundleURL,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default
    ) {
        self.appBundleURL = appBundleURL
        self.homeDirectory = homeDirectory
        self.fileManager = fileManager
    }

    var plistURL: URL {
        homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(Self.label).plist")
    }

    func setEnabled(_ isEnabled: Bool) throws {
        if isEnabled {
            try install()
        } else {
            try remove()
        }
    }

    private func install() throws {
        let launchAgentDirectory = plistURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: launchAgentDirectory, withIntermediateDirectories: true)
        try Self.plistData(appBundlePath: appBundleURL.path).write(to: plistURL, options: .atomic)
        _ = try? launchctl(arguments: ["bootout", guiTarget, plistURL.path])
        try launchctl(arguments: ["bootstrap", guiTarget, plistURL.path])
    }

    private func remove() throws {
        _ = try? launchctl(arguments: ["bootout", guiTarget, plistURL.path])
        if fileManager.fileExists(atPath: plistURL.path) {
            try fileManager.removeItem(at: plistURL)
        }
    }

    private var guiTarget: String {
        "gui/\(getuid())"
    }

    private func launchctl(arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw LoginLaunchControllerError.launchctlFailed(arguments.joined(separator: " "))
        }
    }

    static func plistData(appBundlePath: String) throws -> Data {
        let logDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("MacDog", isDirectory: true)
            .path
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [
                "/usr/bin/open",
                appBundlePath
            ],
            "RunAtLoad": true,
            "StandardOutPath": "\(logDirectory)/monitor.out.log",
            "StandardErrorPath": "\(logDirectory)/monitor.err.log"
        ]
        return try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    }
}

enum LoginLaunchControllerError: LocalizedError {
    case launchctlFailed(String)

    var errorDescription: String? {
        switch self {
        case .launchctlFailed(let command):
            return "자동 실행 설정 변경 실패: launchctl \(command)"
        }
    }
}
