import XCTest
@testable import CodexUsageCore

final class CodexCLIPathRecoveryTests: XCTestCase {
    private var root: URL!
    private let fileManager = FileManager.default

    override func setUpWithError() throws {
        root = fileManager.temporaryDirectory
            .appendingPathComponent("codex-cli-path-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let root {
            try? fileManager.removeItem(at: root)
        }
    }

    func testWorkingConfiguredPathDoesNotSearchOrRewriteTheSavedPath() throws {
        let configured = root.appendingPathComponent("configured/codex")
        let discovered = root.appendingPathComponent("discovered/codex")
        try writeExecutable(at: configured)
        try writeExecutable(at: discovered)
        let store = makeStore()
        let recovery = CodexCLIPathRecovery(
            resolver: CodexCLIResolver(
                environment: ["CODEX_CLI_PATH": configured.path],
                candidates: [discovered.path],
                applicationRoots: []
            ),
            store: store
        )
        var reads: [String] = []

        let used = try recovery.read { url -> String in
            reads.append(url.path)
            return url.path
        }

        XCTAssertEqual(real(used), real(configured))
        XCTAssertEqual(reads.count, 1)
        XCTAssertNil(store.load())
    }

    func testUnusableConfiguredPathIsReplacedAndSaved() throws {
        let configured = root.appendingPathComponent("configured/codex")
        let discovered = root.appendingPathComponent("discovered/codex")
        try writeExecutable(at: configured)
        try writeExecutable(at: discovered)
        let plist = root.appendingPathComponent("LaunchAgents/com.dhseo.macdog.usage-cache.plist")
        try fileManager.createDirectory(at: plist.deletingLastPathComponent(), withIntermediateDirectories: true)
        let original = ["Label": "com.dhseo.macdog.usage-cache", "StartInterval": 60] as [String: Any]
        try PropertyListSerialization.data(fromPropertyList: original, format: .xml, options: 0).write(to: plist)
        let store = CodexCLIPathStore(fileURL: root.appendingPathComponent("codex-cli-path"), launchAgentURL: plist)
        let recovery = CodexCLIPathRecovery(
            resolver: CodexCLIResolver(
                environment: ["CODEX_CLI_PATH": configured.path],
                candidates: [discovered.path],
                applicationRoots: []
            ),
            store: store
        )

        let used = try recovery.read { url -> String in
            if url.path == configured.path {
                throw CodexAppServerError.processLaunchFailed("not a codex cli")
            }
            return url.path
        }

        XCTAssertEqual(real(used), real(discovered))
        XCTAssertEqual(real(try XCTUnwrap(store.load())), real(discovered))
        let savedPlist = try PropertyListSerialization.propertyList(
            from: Data(contentsOf: plist),
            format: nil
        ) as? [String: Any]
        let environment = savedPlist?["EnvironmentVariables"] as? [String: String]
        XCTAssertEqual(environment?["CODEX_CLI_PATH"], discovered.path)
        XCTAssertEqual(savedPlist?["StartInterval"] as? Int, 60)
    }

    func testAccountFailureDoesNotReplaceTheConfiguredPath() throws {
        let configured = root.appendingPathComponent("configured/codex")
        let discovered = root.appendingPathComponent("discovered/codex")
        try writeExecutable(at: configured)
        try writeExecutable(at: discovered)
        let store = makeStore()
        let recovery = CodexCLIPathRecovery(
            resolver: CodexCLIResolver(
                environment: ["CODEX_CLI_PATH": configured.path],
                candidates: [discovered.path],
                applicationRoots: []
            ),
            store: store
        )

        XCTAssertThrowsError(try recovery.read { _ -> String in
            throw CodexAppServerError.rpcError(id: 7, message: "unauthorized")
        }) { error in
            guard case .rpcError = error as? CodexAppServerError else {
                return XCTFail("expected account error, got \(error)")
            }
        }
        XCTAssertNil(store.load())
    }

    func testSearchFailureLeavesTheSavedPathUnset() throws {
        let store = makeStore()
        let recovery = CodexCLIPathRecovery(
            resolver: CodexCLIResolver(
                environment: [:],
                candidates: [root.appendingPathComponent("missing").path],
                applicationRoots: [root.appendingPathComponent("ChatGPT.app")]
            ),
            store: store
        )

        XCTAssertThrowsError(try recovery.read { _ -> String in
            XCTFail("read should not run when no CLI exists")
            return ""
        }) { error in
            guard case .codexBinaryNotFound = error as? CodexAppServerError else {
                return XCTFail("expected not found, got \(error)")
            }
            XCTAssertTrue(error.localizedDescription.contains("LaunchAgent"))
        }
        XCTAssertNil(store.load())
    }

    func testPreInitializeExitIsABadPathButALiveTimeoutIsNot() {
        XCTAssertTrue(
            CodexCLIPathRecovery.isUnusableCLIPath(
                CodexAppServerError.processExitedBeforeInitialize(exitCode: 1)
            )
        )
        XCTAssertFalse(
            CodexCLIPathRecovery.isUnusableCLIPath(
                CodexAppServerError.responseTimedOut(id: CodexAppServerRequestFactory.initializeRequestID)
            )
        )
        XCTAssertFalse(
            CodexCLIPathRecovery.isUnusableCLIPath(
                CodexAppServerError.responseTimedOut(id: CodexAppServerRequestFactory.rateLimitReadRequestID)
            )
        )
    }

    func testLiveInitializeTimeoutDoesNotSearchForAReplacement() throws {
        let configured = root.appendingPathComponent("configured/codex")
        let discovered = root.appendingPathComponent("discovered/codex")
        try writeExecutable(at: configured)
        try writeExecutable(at: discovered)
        let recovery = CodexCLIPathRecovery(
            resolver: CodexCLIResolver(
                environment: ["CODEX_CLI_PATH": configured.path],
                candidates: [discovered.path],
                applicationRoots: []
            ),
            store: makeStore()
        )
        var reads: [String] = []

        XCTAssertThrowsError(try recovery.read { url -> String in
            reads.append(url.path)
            throw CodexAppServerError.responseTimedOut(id: CodexAppServerRequestFactory.initializeRequestID)
        }) { error in
            guard case .responseTimedOut(let id) = error as? CodexAppServerError else {
                return XCTFail("expected initialize timeout, got \(error)")
            }
            XCTAssertEqual(id, CodexAppServerRequestFactory.initializeRequestID)
        }
        XCTAssertEqual(reads, [configured.path])
    }

    func testExitedPathIsNotChosenAgainWhenItIsAlsoTheFixedCandidate() throws {
        let app = root.appendingPathComponent("ChatGPT.app")
        let broken = app.appendingPathComponent("Contents/Resources/old/bin/codex")
        let working = app.appendingPathComponent("Contents/Resources/new/bin/codex")
        try writeExecutable(at: broken)
        try writeExecutable(at: working)
        try writeManifest(at: broken.deletingLastPathComponent().deletingLastPathComponent(), entrypoint: "bin/codex")
        try writeManifest(at: working.deletingLastPathComponent().deletingLastPathComponent(), entrypoint: "bin/codex")
        let store = makeStore()
        let recovery = CodexCLIPathRecovery(
            resolver: CodexCLIResolver(
                environment: ["CODEX_CLI_PATH": broken.path],
                candidates: [broken.path],
                applicationRoots: [app]
            ),
            store: store
        )
        var reads: [String] = []

        let used = try recovery.read { url -> String in
            reads.append(url.path)
            if real(url) == real(broken) {
                throw CodexAppServerError.processExitedBeforeInitialize(exitCode: 1)
            }
            return url.path
        }

        XCTAssertEqual(reads.map { real($0) }, [real(broken), real(working)])
        XCTAssertEqual(real(used), real(working))
        XCTAssertEqual(real(try XCTUnwrap(store.load())), real(working))
    }

    func testStaleConfiguredPathUsesTheSavedExecutableAndReloadsTheAgent() throws {
        let configured = root.appendingPathComponent("configured/codex")
        let saved = root.appendingPathComponent("saved/codex")
        let other = root.appendingPathComponent("other/codex")
        try writeExecutable(at: configured)
        try writeExecutable(at: saved)
        try writeExecutable(at: other)
        let plist = root.appendingPathComponent("LaunchAgents/com.dhseo.macdog.usage-cache.plist")
        try fileManager.createDirectory(at: plist.deletingLastPathComponent(), withIntermediateDirectories: true)
        let original = ["Label": "com.dhseo.macdog.usage-cache", "StartInterval": 60] as [String: Any]
        try PropertyListSerialization.data(fromPropertyList: original, format: .xml, options: 0).write(to: plist)
        var store = CodexCLIPathStore(fileURL: root.appendingPathComponent("codex-cli-path"), launchAgentURL: plist)
        try store.save(saved.path)
        var relaunches = 0
        store.relaunchLoadedAgent = { relaunches += 1 }
        let recovery = CodexCLIPathRecovery(
            resolver: CodexCLIResolver(
                environment: ["CODEX_CLI_PATH": configured.path],
                candidates: [other.path],
                applicationRoots: []
            ),
            store: store
        )
        var reads: [String] = []

        let used = try recovery.read { url -> String in
            reads.append(url.path)
            if real(url) == real(configured) {
                throw CodexAppServerError.processExitedBeforeInitialize(exitCode: 9)
            }
            return url.path
        }

        XCTAssertEqual(reads.map { real($0) }, [real(configured), real(saved)])
        XCTAssertEqual(real(used), real(saved))
        XCTAssertEqual(relaunches, 1)
        XCTAssertFalse(reads.contains(other.path))
    }

    func testUnchangedPlistDoesNotRelaunchTheAgent() throws {
        let executable = root.appendingPathComponent("saved/codex")
        try writeExecutable(at: executable)
        let plist = root.appendingPathComponent("agent.plist")
        let original = ["Label": "com.dhseo.macdog.usage-cache"] as [String: Any]
        try PropertyListSerialization.data(fromPropertyList: original, format: .xml, options: 0).write(to: plist)
        var store = CodexCLIPathStore(fileURL: root.appendingPathComponent("codex-cli-path"), launchAgentURL: plist)
        var relaunches = 0
        store.relaunchLoadedAgent = { relaunches += 1 }

        try store.save(executable.path)
        try store.save(executable.path)

        XCTAssertEqual(relaunches, 1)
    }

    private func makeStore() -> CodexCLIPathStore {
        CodexCLIPathStore(
            fileURL: root.appendingPathComponent("codex-cli-path"),
            launchAgentURL: root.appendingPathComponent("missing-agent.plist")
        )
    }

    private func writeExecutable(at url: URL) throws {
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: url)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    private func real(_ path: String) -> String {
        real(URL(fileURLWithPath: path))
    }

    private func real(_ url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    private func writeManifest(at directory: URL, entrypoint: String) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: ["entrypoint": entrypoint])
        try data.write(to: directory.appendingPathComponent("codex-package.json"))
    }
}
