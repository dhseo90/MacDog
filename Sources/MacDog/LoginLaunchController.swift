import Darwin
import Foundation
import ServiceManagement

enum LoginLaunchStatus: Equatable {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound
    case unknown
}

protocol LoginLaunchServicing {
    var status: LoginLaunchStatus { get }

    func register() throws
    func unregister() throws
}

struct MainAppLoginLaunchService: LoginLaunchServicing {
    var status: LoginLaunchStatus {
        switch SMAppService.mainApp.status {
        case .notRegistered:
            return .notRegistered
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .notFound
        @unknown default:
            return .unknown
        }
    }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }
}

struct LoginLaunchController {
    static let label = "com.dhseo.macdog.monitor"

    private let appBundleURL: URL
    private let homeDirectory: URL
    private let fileManager: FileManager
    private let service: any LoginLaunchServicing
    private let launchctlRunner: ([String]) throws -> Void

    init(
        appBundleURL: URL = Bundle.main.bundleURL,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default,
        service: any LoginLaunchServicing = MainAppLoginLaunchService(),
        launchctlRunner: @escaping ([String]) throws -> Void = LoginLaunchController.runLaunchctl(arguments:)
    ) {
        self.appBundleURL = appBundleURL
        self.homeDirectory = homeDirectory
        self.fileManager = fileManager
        self.service = service
        self.launchctlRunner = launchctlRunner
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
        try removeLegacyLaunchAgent()
        if service.status != .enabled {
            try service.register()
        }
        guard service.status == .enabled else {
            throw LoginLaunchControllerError.loginItemUnavailable(service.status)
        }
    }

    private func remove() throws {
        try removeLegacyLaunchAgent()
        switch service.status {
        case .notRegistered, .notFound:
            return
        case .enabled, .requiresApproval, .unknown:
            try service.unregister()
        }
    }

    private var guiTarget: String {
        "gui/\(getuid())"
    }

    private func removeLegacyLaunchAgent() throws {
        _ = try? launchctl(arguments: ["bootout", guiTarget, plistURL.path])
        if fileManager.fileExists(atPath: plistURL.path) {
            try fileManager.removeItem(at: plistURL)
        }
    }

    private func launchctl(arguments: [String]) throws {
        try launchctlRunner(arguments)
    }

    private static func runLaunchctl(arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw LoginLaunchControllerError.launchctlFailed(arguments.joined(separator: " "))
        }
    }

}

struct LoginLaunchPreferenceCoordinator {
    private let defaults: UserDefaults
    private let setLoginItem: (Bool) throws -> Void

    init(
        defaults: UserDefaults = .standard,
        setLoginItem: @escaping (Bool) throws -> Void = { try LoginLaunchController().setEnabled($0) }
    ) {
        self.defaults = defaults
        self.setLoginItem = setLoginItem
    }

    func setEnabled(_ isEnabled: Bool) throws {
        do {
            try setLoginItem(isEnabled)
            RunnerPreferences.setLoginLaunchEnabled(isEnabled, defaults: defaults)
        } catch {
            RunnerPreferences.setLoginLaunchEnabled(!isEnabled, defaults: defaults)
            throw error
        }
    }
}

enum LoginLaunchControllerError: LocalizedError, Equatable {
    case launchctlFailed(String)
    case loginItemUnavailable(LoginLaunchStatus)

    var errorDescription: String? {
        switch self {
        case .launchctlFailed(let command):
            return "자동 실행 설정 변경 실패: launchctl \(command)"
        case .loginItemUnavailable(let status):
            return "자동 실행 등록 후 macOS 로그인 항목 상태가 활성화되지 않았습니다: \(status)"
        }
    }
}
