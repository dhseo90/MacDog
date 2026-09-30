import Foundation

/// Remembers the Codex CLI path that produced a usage report.
/// The usage-cache LaunchAgent plist is updated when it already exists.
public struct CodexCLIPathStore {
    public static let launchAgentLabel = "com.dhseo.macdog.usage-cache"
    public static let fileName = "codex-cli-path"

    public let fileURL: URL
    public let launchAgentURL: URL
    private let fileManager: FileManager

    public init(fileURL: URL, launchAgentURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.launchAgentURL = launchAgentURL
        self.fileManager = fileManager
    }

    public static func live(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManager = .default
    ) -> CodexCLIPathStore {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MacDog", isDirectory: true)
        let agents = homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
        return CodexCLIPathStore(
            fileURL: support.appendingPathComponent(fileName),
            launchAgentURL: agents.appendingPathComponent("\(launchAgentLabel).plist"),
            fileManager: fileManager
        )
    }

    public func load() -> String? {
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return nil
        }
        let path = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }

    public func save(_ path: String) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        let temporary = directory.appendingPathComponent(".\(Self.fileName).\(UUID().uuidString)")
        try Data(path.utf8).write(to: temporary, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temporary.path)
        if fileManager.fileExists(atPath: fileURL.path) {
            _ = try fileManager.replaceItemAt(fileURL, withItemAt: temporary)
        } else {
            try fileManager.moveItem(at: temporary, to: fileURL)
        }
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        try updateLaunchAgentIfPresent(path: path)
    }

    private func updateLaunchAgentIfPresent(path: String) throws {
        guard fileManager.fileExists(atPath: launchAgentURL.path),
              let data = try? Data(contentsOf: launchAgentURL),
              var plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            return
        }
        var environment = plist["EnvironmentVariables"] as? [String: String] ?? [:]
        environment["CODEX_CLI_PATH"] = path
        plist["EnvironmentVariables"] = environment
        let updated = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try updated.write(to: launchAgentURL, options: .atomic)
    }
}
