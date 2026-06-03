import Foundation

public enum CodexUsageFailureContext: Sendable {
    case status
    case doctor

    var label: String {
        switch self {
        case .status:
            "codex-usage status"
        case .doctor:
            "codex-usage doctor"
        }
    }
}

public struct CodexUsageFailureGuide: Sendable {
    public init() {}

    public func message(for error: Error, context: CodexUsageFailureContext) -> String {
        var lines = ["\(context.label) failed: \(error.localizedDescription)"]
        let nextSteps = nextSteps(for: error, context: context)
        if !nextSteps.isEmpty {
            lines.append("Next steps:")
            lines.append(contentsOf: nextSteps.map { "- \($0)" })
        }
        return lines.joined(separator: "\n")
    }

    private func nextSteps(for error: Error, context: CodexUsageFailureContext) -> [String] {
        if let appServerError = error as? CodexAppServerError {
            return nextSteps(for: appServerError, context: context)
        }

        if error is DecodingError {
            return [
                "Codex app-server schema may have changed; update MacDog and keep the raw response out of logs.",
                doctorStep(context)
            ]
        }

        if error is CodexUsageReportValidationError {
            return [
                "Codex app-server returned a response without the required usage window fields; MacDog refused to cache it as 0% usage.",
                "Restart Codex and retry; if it persists, update MacDog because the internal app-server contract may have changed.",
                doctorStep(context)
            ]
        }

        return [
            "Check that Codex is installed, opens normally, and the network is available.",
            doctorStep(context)
        ]
    }

    private func nextSteps(for error: CodexAppServerError, context: CodexUsageFailureContext) -> [String] {
        switch error {
        case .codexBinaryNotFound(let candidates):
            return [
                "Install the Codex CLI, or set CODEX_CLI_PATH to the executable path.",
                "Checked paths: \(candidates.joined(separator: ", ")).",
                doctorStep(context)
            ]
        case .codexBinaryNotExecutable(let path):
            return [
                "Make the Codex CLI executable or point CODEX_CLI_PATH at a runnable binary.",
                "Current path: \(path).",
                doctorStep(context)
            ]
        case .processLaunchFailed:
            return [
                "Check that Codex opens normally and `codex app-server` can start.",
                "If Codex was just updated, restart Codex and try again.",
                doctorStep(context)
            ]
        case .responseTimedOut, .stdinClosed:
            return [
                "Codex app-server did not answer in time; restart Codex and check network/auth state.",
                doctorStep(context)
            ]
        case .responseMissingResult, .invalidJSONLine:
            return [
                "Codex app-server protocol may have changed; update MacDog before relying on live usage.",
                "Do not paste auth tokens or raw app-server payloads into issue reports.",
                doctorStep(context)
            ]
        case .rpcError(_, let message):
            if Self.looksLikeAuthFailure(message) {
                return [
                    "Open Codex and sign in again, then retry without inspecting ~/.codex/auth.json.",
                    doctorStep(context)
                ]
            }
            return [
                "Codex app-server returned an RPC error; restart Codex and retry.",
                "If it persists, update MacDog because the internal app-server contract may have changed.",
                doctorStep(context)
            ]
        }
    }

    private func doctorStep(_ context: CodexUsageFailureContext) -> String {
        switch context {
        case .status:
            "Run `codex-usage doctor` for a focused access check."
        case .doctor:
            "If this keeps failing, fall back to Codex `/status` inside an active Codex session."
        }
    }

    private static func looksLikeAuthFailure(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        return [
            "auth",
            "login",
            "sign in",
            "signin",
            "unauthorized",
            "forbidden",
            "permission"
        ].contains { lowercased.contains($0) }
    }
}
