import Foundation

/// Uses `CODEX_CLI_PATH` first. When that path cannot produce a usage report,
/// discovery replaces it and the saved path is updated only after the replacement works.
public struct CodexCLIPathRecovery {
    private let resolver: CodexCLIResolver
    private let store: CodexCLIPathStore

    public init(resolver: CodexCLIResolver, store: CodexCLIPathStore) {
        self.resolver = resolver
        self.store = store
    }

    public static func isUnusableCLIPath(_ error: Error) -> Bool {
        guard let appServerError = error as? CodexAppServerError else {
            return false
        }
        switch appServerError {
        case .processLaunchFailed, .stdinClosed, .invalidJSONLine,
             .codexBinaryNotExecutable, .codexBinaryNotFound:
            return true
        case .codexCLIAmbiguous, .codexCLIManifestDamaged, .codexCLIEntrypointRejected,
             .codexCLISearchLimited, .responseTimedOut, .responseMissingResult, .rpcError:
            return false
        }
    }

    public func read<T>(_ read: (URL) throws -> T) throws -> T {
        if let configured = resolver.configuredExecutable() {
            do {
                return try read(configured)
            } catch {
                guard Self.isUnusableCLIPath(error) else {
                    throw error
                }
                let found = try resolver.discover()
                guard !samePath(found, configured) else {
                    throw error
                }
                let value = try read(found)
                try? store.save(found.path)
                return value
            }
        }

        let found = try resolver.discover()
        let value = try read(found)
        try? store.save(found.path)
        return value
    }

    private func samePath(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.resolvingSymlinksInPath().standardizedFileURL.path
            == rhs.resolvingSymlinksInPath().standardizedFileURL.path
    }
}
