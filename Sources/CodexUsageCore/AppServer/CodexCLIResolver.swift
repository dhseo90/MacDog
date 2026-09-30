import Foundation

public struct CodexCLISearchLimits: Equatable, Sendable {
    public var maxDepth: Int
    public var maxEntries: Int

    public init(maxDepth: Int, maxEntries: Int) {
        self.maxDepth = maxDepth
        self.maxEntries = maxEntries
    }

    /// Deep enough for `CodexCLI.app/Contents/MacOS/codex` and a full current ChatGPT.app walk.
    public static let standard = CodexCLISearchLimits(maxDepth: 12, maxEntries: 8_000)
}

public struct CodexCLIResolver {
    public static let defaultCandidates = [
        "/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex",
        "/Applications/ChatGPT.app/Contents/Resources/codex",
        "/Applications/Codex.app/Contents/Resources/codex",
        "/opt/homebrew/bin/codex",
        "/usr/local/bin/codex"
    ]

    public static func defaultApplicationRoots(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> [URL] {
        let homeApplications = homeDirectory.appendingPathComponent("Applications", isDirectory: true)
        return [
            URL(fileURLWithPath: "/Applications/ChatGPT.app", isDirectory: true),
            homeApplications.appendingPathComponent("ChatGPT.app", isDirectory: true),
            URL(fileURLWithPath: "/Applications/Codex.app", isDirectory: true),
            homeApplications.appendingPathComponent("Codex.app", isDirectory: true)
        ]
    }

    private let environment: [String: String]
    private let fileManager: FileManager
    private let candidates: [String]
    private let applicationRoots: [URL]
    private let searchLimits: CodexCLISearchLimits

    public init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        candidates: [String] = CodexCLIResolver.defaultCandidates,
        applicationRoots: [URL]? = nil,
        searchLimits: CodexCLISearchLimits = .standard,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.environment = environment
        self.fileManager = fileManager
        self.candidates = candidates
        self.applicationRoots = applicationRoots ?? Self.defaultApplicationRoots(homeDirectory: homeDirectory)
        self.searchLimits = searchLimits
    }

    public func resolve() throws -> URL {
        if let override = environment["CODEX_CLI_PATH"], !override.isEmpty {
            return try executableURL(at: override)
        }

        for candidate in candidates where isRunnableFile(at: candidate) {
            return URL(fileURLWithPath: candidate)
        }

        let scans = applicationRoots.map { scan($0) }
        for scan in scans {
            if scan.hitEntryLimit {
                throw CodexAppServerError.codexCLISearchLimited(
                    appPath: scan.root.path,
                    maxEntries: searchLimits.maxEntries,
                    maxDepth: searchLimits.maxDepth
                )
            }
            if let resolved = try resolvedURL(from: scan) {
                return resolved
            }
        }

        throw CodexAppServerError.codexBinaryNotFound(
            checked: candidates,
            searchedApps: scans.map(\.displayPath)
        )
    }

    private func executableURL(at path: String) throws -> URL {
        guard isRunnableFile(at: path) else {
            throw CodexAppServerError.codexBinaryNotExecutable(path)
        }
        return URL(fileURLWithPath: path)
    }

    private func isRunnableFile(at path: String) -> Bool {
        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            return false
        }
        return fileManager.isExecutableFile(atPath: path)
    }

    private func resolvedURL(from scan: AppScan) throws -> URL? {
        guard scan.exists else { return nil }
        let validPaths = uniquePaths(scan.validExecutables)
        let packageCount = validPaths.count + scan.damaged.count + scan.rejected.count
        if packageCount > 0 {
            if validPaths.count == 1, scan.damaged.isEmpty, scan.rejected.isEmpty {
                return URL(fileURLWithPath: validPaths[0])
            }
            if scan.damaged.count == 1, validPaths.isEmpty, scan.rejected.isEmpty {
                throw CodexAppServerError.codexCLIManifestDamaged(
                    path: scan.damaged[0].path,
                    reason: scan.damaged[0].reason
                )
            }
            if scan.rejected.count == 1, validPaths.isEmpty, scan.damaged.isEmpty {
                let rejected = scan.rejected[0]
                throw CodexAppServerError.codexCLIEntrypointRejected(
                    manifestPath: rejected.manifestPath,
                    entrypoint: rejected.entrypoint,
                    reason: rejected.reason
                )
            }
            throw CodexAppServerError.codexCLIAmbiguous(scan.conflictDescriptions(validPaths: validPaths))
        }
        let barePaths = uniquePaths(scan.bareExecutables)
        if barePaths.count == 1 {
            return URL(fileURLWithPath: barePaths[0])
        }
        if barePaths.count > 1 {
            throw CodexAppServerError.codexCLIAmbiguous(barePaths)
        }
        return nil
    }

    private func scan(_ root: URL) -> AppScan {
        var scan = AppScan(root: root.standardizedFileURL)
        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return scan
        }
        scan.exists = true
        let rootReal = realPath(of: root) ?? root.standardizedFileURL.path
        var queue: [(url: URL, depth: Int)] = [(root, 0)]
        var seenDirectories: Set<String> = [rootReal]
        var entries = 0

        while !queue.isEmpty {
            let current = queue.removeFirst()
            let children: [URL]
            do {
                children = try fileManager.contentsOfDirectory(
                    at: current.url,
                    includingPropertiesForKeys: nil,
                    options: []
                )
            } catch {
                continue
            }
            for child in children.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                entries += 1
                if entries > searchLimits.maxEntries {
                    scan.hitEntryLimit = true
                    return scan
                }
                classify(child, root: root, rootReal: rootReal, into: &scan)
                let childDepth = current.depth + 1
                guard childDepth < searchLimits.maxDepth, shouldDescend(child, rootReal: rootReal) else {
                    continue
                }
                let childReal = realPath(of: child) ?? child.standardizedFileURL.path
                if seenDirectories.insert(childReal).inserted {
                    queue.append((child, childDepth))
                }
            }
        }
        return scan
    }

    private func classify(_ child: URL, root: URL, rootReal: String, into scan: inout AppScan) {
        switch child.lastPathComponent {
        case "codex-package.json":
            classifyManifest(child, root: root, rootReal: rootReal, into: &scan)
        case "codex":
            if let accepted = acceptedExecutable(child, rootReal: rootReal) {
                scan.bareExecutables.append(accepted)
            }
        default:
            break
        }
    }

    private func classifyManifest(_ manifest: URL, root: URL, rootReal: String, into scan: inout AppScan) {
        let manifestReal = realPath(of: manifest)
        guard let manifestReal, isInside(manifestReal, root: rootReal) else {
            scan.rejected.append(
                RejectedEntrypoint(
                    manifestPath: manifest.standardizedFileURL.path,
                    entrypoint: "",
                    reason: "manifest symlink resolves outside the app bundle"
                )
            )
            return
        }
        guard isRegularFile(at: manifestReal) else {
            scan.damaged.append((path: manifest.standardizedFileURL.path, reason: "manifest is not a regular file"))
            return
        }
        let data: Data
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: manifestReal))
        } catch {
            scan.damaged.append((path: manifest.standardizedFileURL.path, reason: "manifest is unreadable"))
            return
        }
        if data.count > 65_536 {
            scan.damaged.append((path: manifest.standardizedFileURL.path, reason: "manifest is too large"))
            return
        }
        switch parsedEntrypoint(data) {
        case .invalid(let reason):
            scan.damaged.append((path: manifest.standardizedFileURL.path, reason: reason))
        case .value(let entrypoint):
            switch resolvedEntrypoint(entrypoint, manifest: manifest, root: root, rootReal: rootReal) {
            case .invalid(let reason):
                scan.rejected.append(
                    RejectedEntrypoint(
                        manifestPath: manifest.standardizedFileURL.path,
                        entrypoint: entrypoint,
                        reason: reason
                    )
                )
            case .value(let executable):
                scan.validExecutables.append(executable)
            }
        }
    }

    private func parsedEntrypoint(_ data: Data) -> EntrypointValue<String> {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            return .invalid("manifest is not valid JSON")
        }
        guard let fields = object as? [String: Any] else {
            return .invalid("manifest is not a JSON object")
        }
        guard let raw = fields["entrypoint"] else {
            return .invalid("entrypoint is missing")
        }
        guard let entrypoint = raw as? String else {
            return .invalid("entrypoint is not a string")
        }
        if entrypoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || entrypoint.contains("\0") {
            return .invalid("entrypoint is empty")
        }
        return .value(entrypoint)
    }

    private func resolvedEntrypoint(
        _ entrypoint: String,
        manifest: URL,
        root: URL,
        rootReal: String
    ) -> EntrypointValue<URL> {
        let lexical = lexicalEntrypointURL(entrypoint, manifest: manifest)
        guard isInside(lexical.standardizedFileURL.path, root: root.standardizedFileURL.path) else {
            return .invalid("entrypoint resolves outside the app bundle")
        }
        guard let executable = acceptedExecutable(lexical, rootReal: rootReal) else {
            if let real = realPath(of: lexical), !isInside(real, root: rootReal) {
                return .invalid("entrypoint symlink resolves outside the app bundle")
            }
            return .invalid("entrypoint is not an executable regular file inside the app")
        }
        return .value(executable)
    }

    private func lexicalEntrypointURL(_ entrypoint: String, manifest: URL) -> URL {
        if entrypoint.hasPrefix("/") {
            return URL(fileURLWithPath: entrypoint).standardizedFileURL
        }
        var url = manifest.deletingLastPathComponent()
        for part in entrypoint.split(separator: "/", omittingEmptySubsequences: true) {
            if part == "." {
                continue
            }
            if part == ".." {
                url.deleteLastPathComponent()
            } else {
                url.appendPathComponent(String(part))
            }
        }
        return url.standardizedFileURL
    }

    private func acceptedExecutable(_ url: URL, rootReal: String) -> URL? {
        let lexical = url.standardizedFileURL
        guard let real = realPath(of: lexical), isInside(real, root: rootReal) else {
            return nil
        }
        guard isRegularFile(at: real), fileManager.isExecutableFile(atPath: real) else {
            return nil
        }
        return lexical
    }

    private func shouldDescend(_ url: URL, rootReal: String) -> Bool {
        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return false
        }
        guard let real = realPath(of: url) else { return false }
        return isInside(real, root: rootReal)
    }

    private func isRegularFile(at path: String) -> Bool {
        guard let type = try? fileManager.attributesOfItem(atPath: path)[.type] as? FileAttributeType else {
            return false
        }
        return type == .typeRegular
    }

    private func realPath(of url: URL) -> String? {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    private func isInside(_ path: String, root: String) -> Bool {
        let candidate = comparablePath(path)
        let container = comparablePath(root)
        return candidate == container || candidate.hasPrefix(container + "/")
    }

    private func comparablePath(_ path: String) -> String {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
    }

    private func uniquePaths(_ urls: [URL]) -> [String] {
        var seen: Set<String> = []
        var paths: [String] = []
        for url in urls {
            let path = (realPath(of: url) ?? url.standardizedFileURL.path)
            if seen.insert(path).inserted {
                paths.append(url.standardizedFileURL.path)
            }
        }
        return paths
    }
}

private enum EntrypointValue<Value> {
    case value(Value)
    case invalid(String)
}

private struct RejectedEntrypoint {
    var manifestPath: String
    var entrypoint: String
    var reason: String
}

private struct AppScan {
    var root: URL
    var exists = false
    var hitEntryLimit = false
    var validExecutables: [URL] = []
    var damaged: [(path: String, reason: String)] = []
    var rejected: [RejectedEntrypoint] = []
    var bareExecutables: [URL] = []

    var displayPath: String {
        exists ? root.path : "\(root.path) (not present)"
    }

    func conflictDescriptions(validPaths: [String]) -> [String] {
        var lines = validPaths
        lines.append(contentsOf: damaged.map { "\($0.path) (damaged manifest: \($0.reason))" })
        lines.append(contentsOf: rejected.map {
            "\($0.manifestPath) (rejected entrypoint \($0.entrypoint): \($0.reason))"
        })
        return lines
    }
}
