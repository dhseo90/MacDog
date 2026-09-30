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
        case .processLaunchFailed, .processExitedBeforeInitialize, .stdinClosed, .invalidJSONLine,
             .codexBinaryNotExecutable, .codexBinaryNotFound:
            return true
        case .codexCLIAmbiguous, .codexCLIManifestDamaged, .codexCLIEntrypointRejected,
             .codexCLISearchLimited, .responseTimedOut, .responseMissingResult, .rpcError:
            return false
        }
    }

    public func read<T>(_ read: (URL) throws -> T) throws -> T {
        var excluded: [URL] = []
        if let configured = resolver.configuredExecutable() {
            do {
                return try read(configured)
            } catch {
                guard Self.isUnusableCLIPath(error) else {
                    throw error
                }
                excluded.append(configured)
                if let saved = runnableSavedPath(), !excluded.contains(where: { samePath($0, saved) }) {
                    do {
                        let value = try read(saved)
                        try? store.save(saved.path, reloadEvenIfUnchanged: true)
                        return value
                    } catch {
                        guard Self.isUnusableCLIPath(error) else {
                            throw error
                        }
                        excluded.append(saved)
                    }
                }
            }
        }
        return try readNextCandidate(read, excluding: &excluded)
    }

    private func runnableSavedPath() -> URL? {
        guard let path = store.load() else { return nil }
        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              !isDirectory.boolValue,
              FileManager.default.isExecutableFile(atPath: path)
        else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }

    private func readNextCandidate<T>(_ read: (URL) throws -> T, excluding excluded: inout [URL]) throws -> T {
        while true {
            let found = try resolver.discover(excluding: excluded)
            if excluded.contains(where: { samePath($0, found) }) {
                throw CodexAppServerError.codexBinaryNotFound(checked: [found.path], searchedApps: [])
            }
            do {
                let value = try read(found)
                try? store.save(found.path)
                return value
            } catch {
                guard Self.isUnusableCLIPath(error) else {
                    throw error
                }
                excluded.append(found)
            }
        }
    }

    private func samePath(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.resolvingSymlinksInPath().standardizedFileURL.path
            == rhs.resolvingSymlinksInPath().standardizedFileURL.path
    }
}
