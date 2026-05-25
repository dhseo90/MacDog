import Foundation

public enum CodexAppServerError: Error, LocalizedError, Equatable {
    case codexBinaryNotFound([String])
    case codexBinaryNotExecutable(String)
    case processLaunchFailed(String)
    case responseTimedOut(id: Int)
    case responseMissingResult(id: Int)
    case rpcError(id: Int, message: String)
    case stdinClosed
    case invalidJSONLine(String)

    public var errorDescription: String? {
        switch self {
        case .codexBinaryNotFound(let candidates):
            "Codex CLI not found. Checked: \(candidates.joined(separator: ", "))"
        case .codexBinaryNotExecutable(let path):
            "Codex CLI is not executable at \(path)."
        case .processLaunchFailed(let detail):
            "Failed to launch Codex app-server: \(detail)"
        case .responseTimedOut(let id):
            "Timed out waiting for Codex app-server response id \(id)."
        case .responseMissingResult(let id):
            "Codex app-server response id \(id) did not include a result."
        case .rpcError(let id, let message):
            "Codex app-server response id \(id) returned an error: \(message)"
        case .stdinClosed:
            "Codex app-server stdin is closed."
        case .invalidJSONLine(let line):
            "Codex app-server returned invalid JSON: \(line)"
        }
    }
}

