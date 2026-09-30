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
        URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
    }
}
