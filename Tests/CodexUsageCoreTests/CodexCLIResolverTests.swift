import XCTest
@testable import CodexUsageCore

final class CodexCLIResolverTests: XCTestCase {
    private var root: URL!
    private let fileManager = FileManager.default

    override func setUpWithError() throws {
        root = fileManager.temporaryDirectory
            .appendingPathComponent("codex-cli-resolver-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let root {
            try? fileManager.removeItem(at: root)
        }
    }

    func testDefaultSearchRootsAreTheFourAppBundles() {
        let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)
        XCTAssertEqual(
            CodexCLIResolver.defaultApplicationRoots(homeDirectory: home).map(\.path),
            [
                "/Applications/ChatGPT.app",
                "/Users/example/Applications/ChatGPT.app",
                "/Applications/Codex.app",
                "/Users/example/Applications/Codex.app"
            ]
        )
    }

    func testFixedCandidateWinsOverAmbiguousPackagesInsideTheApp() throws {
        let fixed = root.appendingPathComponent("fixed/codex")
        try writeExecutable(at: fixed)
        let app = try makeApp("ChatGPT.app")
        try writePackage(at: app.appendingPathComponent("one"))
        try writePackage(at: app.appendingPathComponent("two"))

        let resolved = try resolver(candidates: [fixed.path], roots: [app]).resolve()

        XCTAssertEqual(real(resolved), real(fixed))
    }

    func testRunnableOverrideIsUsedWithoutSearching() throws {
        let override = root.appendingPathComponent("override/codex")
        let other = root.appendingPathComponent("other/codex")
        try writeExecutable(at: override)
        try writeExecutable(at: other)

        let resolved = try resolver(
            environment: ["CODEX_CLI_PATH": override.path],
            candidates: [other.path],
            roots: []
        ).resolve()

        XCTAssertEqual(real(resolved), real(override))
    }

    func testMissingOverrideFallsThroughToDiscovery() throws {
        let fixed = root.appendingPathComponent("fixed/codex")
        try writeExecutable(at: fixed)
        let missing = root.appendingPathComponent("missing-codex").path

        let resolved = try resolver(
            environment: ["CODEX_CLI_PATH": missing],
            candidates: [fixed.path],
            roots: [try makeApp("ChatGPT.app")]
        ).resolve()

        XCTAssertEqual(real(resolved), real(fixed))
    }

    func testNonExecutableOverrideFallsThroughToDiscovery() throws {
        let override = root.appendingPathComponent("blocked/codex")
        try writeExecutable(at: override)
        try fileManager.setAttributes([.posixPermissions: 0o644], ofItemAtPath: override.path)
        let fixed = root.appendingPathComponent("fixed/codex")
        try writeExecutable(at: fixed)

        let resolved = try resolver(
            environment: ["CODEX_CLI_PATH": override.path],
            candidates: [fixed.path],
            roots: []
        ).resolve()

        XCTAssertEqual(real(resolved), real(fixed))
    }

    func testMovedPackageUsesManifestEntrypointInsteadOfNestedBinary() throws {
        let app = try makeApp("ChatGPT.app")
        let package = app.appendingPathComponent("Contents/Resources/relocated")
        try writeExecutable(at: package.appendingPathComponent("CodexCLI.app/Contents/MacOS/codex"))
        try writePackage(at: package, executableRelativePath: "bin/codex")
        let absent = root.appendingPathComponent("absent-codex").path

        let resolved = try resolver(candidates: [absent], roots: [app]).resolve()

        XCTAssertTrue(resolved.path.hasSuffix("/relocated/bin/codex"))
        XCTAssertFalse(resolved.path.contains("/MacOS/codex"))
    }

    func testNestedAppBinaryIsFoundWhenManifestIsAbsent() throws {
        let app = try makeApp("ChatGPT.app")
        let binary = app.appendingPathComponent("Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex")
        try writeExecutable(at: binary)

        let resolved = try resolver(candidates: [], roots: [app]).resolve()

        XCTAssertEqual(real(resolved), real(binary))
    }

    func testMultipleManifestsInOneAppAreAmbiguous() throws {
        let app = try makeApp("ChatGPT.app")
        let first = try writePackage(at: app.appendingPathComponent("pkg-a"))
        let second = try writePackage(at: app.appendingPathComponent("pkg-b"))

        XCTAssertThrowsError(try resolver(candidates: [], roots: [app]).resolve()) { error in
            guard case .codexCLIAmbiguous(let paths) = error as? CodexAppServerError else {
                return XCTFail("expected ambiguous candidates, got \(error)")
            }
            XCTAssertTrue(paths.contains { real($0) == real(first) })
            XCTAssertTrue(paths.contains { real($0) == real(second) })
            XCTAssertTrue(error.localizedDescription.contains("LaunchAgent"))
        }
    }

    func testManifestsThatAgreeOnOneExecutableAreNotAmbiguous() throws {
        let app = try makeApp("ChatGPT.app")
        let shared = app.appendingPathComponent("shared/codex")
        try writeExecutable(at: shared)
        try writeManifest(at: app.appendingPathComponent("pkg-a"), entrypoint: "../shared/codex")
        let linkDirectory = app.appendingPathComponent("pkg-b/bin")
        try fileManager.createDirectory(at: linkDirectory, withIntermediateDirectories: true)
        try fileManager.createSymbolicLink(
            at: linkDirectory.appendingPathComponent("codex"),
            withDestinationURL: shared
        )
        try writeManifest(at: app.appendingPathComponent("pkg-b"), entrypoint: "bin/codex")

        let resolved = try resolver(candidates: [], roots: [app]).resolve()

        XCTAssertEqual(real(resolved), real(shared))
    }

    func testMultipleBareBinariesAreAmbiguous() throws {
        let app = try makeApp("ChatGPT.app")
        let first = app.appendingPathComponent("A/codex")
        let second = app.appendingPathComponent("B/codex")
        try writeExecutable(at: first)
        try writeExecutable(at: second)

        XCTAssertThrowsError(try resolver(candidates: [], roots: [app]).resolve()) { error in
            guard case .codexCLIAmbiguous(let paths) = error as? CodexAppServerError else {
                return XCTFail("expected ambiguous binaries, got \(error)")
            }
            XCTAssertTrue(paths.contains { real($0) == real(first) })
            XCTAssertTrue(paths.contains { real($0) == real(second) })
        }
    }

    func testEarlierAppWinsOverLaterApp() throws {
        let chatGPT = try makeApp("ChatGPT.app")
        let codex = try makeApp("Codex.app")
        let preferred = try writePackage(at: chatGPT.appendingPathComponent("pkg"))
        _ = try writePackage(at: codex.appendingPathComponent("pkg"))

        let resolved = try resolver(candidates: [], roots: [chatGPT, codex]).resolve()

        XCTAssertEqual(real(resolved), real(preferred))
    }

    func testEntrypointSymlinkOutsideTheAppIsRejected() throws {
        let app = try makeApp("ChatGPT.app")
        let outside = root.appendingPathComponent("outside/codex")
        try writeExecutable(at: outside)
        let package = app.appendingPathComponent("Contents/Resources/codex-cli")
        try fileManager.createDirectory(at: package.appendingPathComponent("bin"), withIntermediateDirectories: true)
        try fileManager.createSymbolicLink(
            at: package.appendingPathComponent("bin/codex"),
            withDestinationURL: outside
        )
        try writeManifest(at: package, entrypoint: "bin/codex")

        XCTAssertThrowsError(try resolver(candidates: [], roots: [app]).resolve()) { error in
            guard case .codexCLIEntrypointRejected(_, let entrypoint, let reason) = error as? CodexAppServerError else {
                return XCTFail("expected rejected entrypoint, got \(error)")
            }
            XCTAssertEqual(entrypoint, "bin/codex")
            XCTAssertTrue(reason.contains("outside"))
            XCTAssertFalse(error.localizedDescription.contains(outside.path))
        }
    }

    func testEntrypointParentEscapeIsRejected() throws {
        let app = try makeApp("ChatGPT.app")
        let outside = root.appendingPathComponent("outside/codex")
        try writeExecutable(at: outside)
        let package = app.appendingPathComponent("Contents/Resources/pkg")
        try writeManifest(at: package, entrypoint: "../../../../outside/codex")

        XCTAssertThrowsError(try resolver(candidates: [], roots: [app]).resolve()) { error in
            guard case .codexCLIEntrypointRejected(_, _, let reason) = error as? CodexAppServerError else {
                return XCTFail("expected rejected entrypoint, got \(error)")
            }
            XCTAssertTrue(reason.contains("outside"))
            XCTAssertFalse(error.localizedDescription.contains(outside.path))
        }
    }

    func testEntrypointInsideTheAppMayBeASymlinkToAnotherFileInsideTheApp() throws {
        let app = try makeApp("ChatGPT.app")
        let package = app.appendingPathComponent("Contents/Resources/codex-cli")
        let binary = package.appendingPathComponent("CodexCLI.app/Contents/MacOS/codex")
        try writeExecutable(at: binary)
        try fileManager.createDirectory(at: package.appendingPathComponent("bin"), withIntermediateDirectories: true)
        try fileManager.createSymbolicLink(
            at: package.appendingPathComponent("bin/codex"),
            withDestinationURL: binary
        )
        try writeManifest(at: package, entrypoint: "bin/codex")

        let resolved = try resolver(candidates: [], roots: [app]).resolve()

        XCTAssertTrue(resolved.path.hasSuffix("/bin/codex"))
        XCTAssertEqual(
            resolved.resolvingSymlinksInPath().standardizedFileURL.path,
            binary.resolvingSymlinksInPath().standardizedFileURL.path
        )
    }

    func testDirectoryEntrypointIsRejected() throws {
        let app = try makeApp("ChatGPT.app")
        let package = app.appendingPathComponent("pkg")
        try fileManager.createDirectory(at: package.appendingPathComponent("bin"), withIntermediateDirectories: true)
        try writeManifest(at: package, entrypoint: "bin")

        XCTAssertThrowsError(try resolver(candidates: [], roots: [app]).resolve()) { error in
            guard case .codexCLIEntrypointRejected(_, let entrypoint, let reason) = error as? CodexAppServerError else {
                return XCTFail("expected rejected entrypoint, got \(error)")
            }
            XCTAssertEqual(entrypoint, "bin")
            XCTAssertTrue(reason.contains("regular file"))
        }
    }

    func testCorruptManifestIsNotReportedAsMissing() throws {
        let app = try makeApp("ChatGPT.app")
        let manifest = app.appendingPathComponent("codex-cli/codex-package.json")
        try fileManager.createDirectory(at: manifest.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{".utf8).write(to: manifest)
        try writeExecutable(at: app.appendingPathComponent("CodexCLI.app/Contents/MacOS/codex"))

        XCTAssertThrowsError(try resolver(candidates: [], roots: [app]).resolve()) { error in
            guard case .codexCLIManifestDamaged(let path, let reason) = error as? CodexAppServerError else {
                return XCTFail("expected damaged manifest, got \(error)")
            }
            XCTAssertEqual(real(path), real(manifest))
            XCTAssertTrue(reason.contains("JSON"))
            XCTAssertTrue(error.localizedDescription.contains("not a missing manifest"))
            XCTAssertFalse(error.localizedDescription.contains("Codex CLI not found"))
        }
    }

    func testAbsentManifestAndBinaryReportsSearchedApps() throws {
        let app = try makeApp("ChatGPT.app")
        let absent = root.appendingPathComponent("absent-codex").path

        XCTAssertThrowsError(try resolver(candidates: [absent], roots: [app]).resolve()) { error in
            guard case .codexBinaryNotFound(let checked, let searchedApps) = error as? CodexAppServerError else {
                return XCTFail("expected not found, got \(error)")
            }
            XCTAssertEqual(checked, [absent])
            XCTAssertTrue(searchedApps.contains { real($0) == real(app) })
            XCTAssertTrue(error.localizedDescription.contains("LaunchAgent"))
            XCTAssertFalse(error.localizedDescription.contains("damaged"))
        }
    }

    func testEntryLimitDoesNotUseAPartialMatchOrALaterApp() throws {
        let chatGPT = try makeApp("ChatGPT.app")
        for name in ["a0", "a1", "a2"] {
            try Data("x".utf8).write(to: chatGPT.appendingPathComponent(name))
        }
        _ = try writePackage(at: chatGPT.appendingPathComponent("z-codex"))
        let codex = try makeApp("Codex.app")
        _ = try writePackage(at: codex.appendingPathComponent("pkg"))

        XCTAssertThrowsError(
            try resolver(
                candidates: [],
                roots: [chatGPT, codex],
                limits: CodexCLISearchLimits(maxDepth: 12, maxEntries: 3)
            ).resolve()
        ) { error in
            guard case .codexCLISearchLimited(let appPath, let maxEntries, _) = error as? CodexAppServerError else {
                return XCTFail("expected search limit, got \(error)")
            }
            XCTAssertEqual(real(appPath), real(chatGPT))
            XCTAssertEqual(maxEntries, 3)
            XCTAssertFalse(error.localizedDescription.contains("/Codex.app/"))
        }
    }

    private func real(_ url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    private func real(_ path: String) -> String {
        real(URL(fileURLWithPath: path))
    }

    private func resolver(
        environment: [String: String] = [:],
        candidates: [String],
        roots: [URL],
        limits: CodexCLISearchLimits = .standard
    ) -> CodexCLIResolver {
        CodexCLIResolver(
            environment: environment,
            candidates: candidates,
            applicationRoots: roots,
            searchLimits: limits,
            homeDirectory: root
        )
    }

    private func makeApp(_ name: String) throws -> URL {
        let app = root.appendingPathComponent(name, isDirectory: true)
        try fileManager.createDirectory(at: app, withIntermediateDirectories: true)
        return app
    }

    @discardableResult
    private func writePackage(at directory: URL, executableRelativePath: String = "bin/codex") throws -> URL {
        let executable = directory.appendingPathComponent(executableRelativePath)
        try writeExecutable(at: executable)
        try writeManifest(at: directory, entrypoint: executableRelativePath)
        return executable
    }

    private func writeManifest(at directory: URL, entrypoint: String) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let manifest = directory.appendingPathComponent("codex-package.json")
        let data = try JSONSerialization.data(withJSONObject: ["entrypoint": entrypoint])
        try data.write(to: manifest)
    }

    private func writeExecutable(at url: URL, contents: String = "#!/bin/sh\nexit 0\n") throws {
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: url)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }
}
