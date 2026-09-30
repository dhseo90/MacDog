import Foundation

public enum CodexAppServerError: Error, LocalizedError, Equatable {
    case codexBinaryNotFound(checked: [String], searchedApps: [String])
    case codexBinaryNotExecutable(String)
    case codexCLIAmbiguous([String])
    case codexCLIManifestDamaged(path: String, reason: String)
    case codexCLIEntrypointRejected(manifestPath: String, entrypoint: String, reason: String)
    case codexCLISearchLimited(appPath: String, maxEntries: Int, maxDepth: Int)
    case processLaunchFailed(String)
    /// The CLI process ended before the app-server `initialize` response. A timeout while that process is still running is `responseTimedOut` instead.
    case processExitedBeforeInitialize(exitCode: Int)
    case responseTimedOut(id: Int)
    case responseMissingResult(id: Int)
    case rpcError(id: Int, message: String)
    case stdinClosed
    case invalidJSONLine(String)

    /// A terminal `export` does not change the path the cache LaunchAgent already loaded.
    public static let launchAgentOverrideNote =
        "Automatic refresh reads CODEX_CLI_PATH from the usage cache LaunchAgent. A terminal export alone does not change that saved path. When a working Codex CLI is found, that path is saved."

    public var errorDescription: String? {
        switch self {
        case .codexBinaryNotFound(let checked, let searchedApps):
            "Codex CLI not found. Checked: \(checked.joined(separator: ", ")). Searched apps: \(searchedApps.joined(separator: ", ")). \(Self.launchAgentOverrideNote)"
        case .codexBinaryNotExecutable(let path):
            "Codex CLI is not executable at \(path). \(Self.launchAgentOverrideNote)"
        case .codexCLIAmbiguous(let paths):
            "Codex CLI location is ambiguous. Candidates: \(paths.joined(separator: ", ")). Set CODEX_CLI_PATH to the executable path. \(Self.launchAgentOverrideNote)"
        case .codexCLIManifestDamaged(let path, let reason):
            "Codex CLI package manifest is damaged at \(path): \(reason). This is not a missing manifest. Set CODEX_CLI_PATH to the executable path. \(Self.launchAgentOverrideNote)"
        case .codexCLIEntrypointRejected(let manifestPath, let entrypoint, let reason):
            "Codex CLI package entrypoint was rejected at \(manifestPath) (entrypoint \(entrypoint)): \(reason). Set CODEX_CLI_PATH to the executable path. \(Self.launchAgentOverrideNote)"
        case .codexCLISearchLimited(let appPath, let maxEntries, let maxDepth):
            "Codex CLI search stopped at \(appPath) after \(maxEntries) entries (depth limit \(maxDepth)). Set CODEX_CLI_PATH to the executable path. \(Self.launchAgentOverrideNote)"
        case .processLaunchFailed(let detail):
            "Failed to launch Codex app-server: \(detail)"
        case .processExitedBeforeInitialize(let exitCode):
            "Codex CLI exited with status \(exitCode) before app-server initialization completed."
        case .responseTimedOut(let id):
            "Timed out waiting for Codex app-server response id \(id)."
        case .responseMissingResult(let id):
            "Codex app-server response id \(id) did not include a result."
        case .rpcError(let id, let message):
            "Codex app-server response id \(id) returned an error: \(message)"
        case .stdinClosed:
            "Codex app-server stdin is closed."
        case .invalidJSONLine:
            "Codex app-server returned invalid JSON."
        }
    }
}
