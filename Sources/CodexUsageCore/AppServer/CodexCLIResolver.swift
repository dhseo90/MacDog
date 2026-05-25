import Foundation

public struct CodexCLIResolver {
    public static let defaultCandidates = [
        "/Applications/Codex.app/Contents/Resources/codex",
        "/opt/homebrew/bin/codex",
        "/usr/local/bin/codex"
    ]

    private let environment: [String: String]
    private let fileManager: FileManager

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) {
        self.environment = environment
        self.fileManager = fileManager
    }

    public func resolve() throws -> URL {
        if let override = environment["CODEX_CLI_PATH"], !override.isEmpty {
            return try executableURL(at: override)
        }

        for candidate in Self.defaultCandidates where fileManager.isExecutableFile(atPath: candidate) {
            return URL(fileURLWithPath: candidate)
        }

        throw CodexAppServerError.codexBinaryNotFound(Self.defaultCandidates)
    }

    private func executableURL(at path: String) throws -> URL {
        guard fileManager.isExecutableFile(atPath: path) else {
            throw CodexAppServerError.codexBinaryNotExecutable(path)
        }
        return URL(fileURLWithPath: path)
    }
}
