import XCTest
@testable import CodexUsageCore

final class CodexAppServerClientTests: XCTestCase {
    func testResolverPrefersPackageEntrypointBeforeLegacyPaths() {
        XCTAssertEqual(
            CodexCLIResolver.defaultCandidates.first,
            "/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex"
        )
        XCTAssertFalse(
            CodexCLIResolver.defaultCandidates.contains(
                "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex"
            )
        )
        XCTAssertTrue(
            CodexCLIResolver.defaultCandidates.contains(
                "/Applications/ChatGPT.app/Contents/Resources/codex"
            )
        )
        XCTAssertTrue(
            CodexCLIResolver.defaultCandidates.contains(
                "/Applications/Codex.app/Contents/Resources/codex"
            )
        )
    }

    func testDefaultWorkingDirectoryUsesTemporaryDirectory() {
        XCTAssertEqual(CodexAppServerClient.defaultWorkingDirectoryURL.path, "/tmp")
    }

    func testProxySubcommandIsPreferredWhenDaemonIsAvailable() {
        XCTAssertEqual(
            CodexAppServerClient.argumentCandidates(proxySubcommandAvailable: true, daemonAvailable: true),
            [
                CodexAppServerClient.proxyArguments,
                CodexAppServerClient.legacyArguments
            ]
        )
    }

    func testLegacyInvocationIsUsedWhenProxySubcommandIsUnavailable() {
        XCTAssertEqual(
            CodexAppServerClient.argumentCandidates(proxySubcommandAvailable: false, daemonAvailable: true),
            [
                CodexAppServerClient.legacyArguments
            ]
        )
    }

    func testLegacyInvocationIsUsedWhenProxyDaemonIsUnavailable() {
        XCTAssertEqual(
            CodexAppServerClient.argumentCandidates(proxySubcommandAvailable: true, daemonAvailable: false),
            [
                CodexAppServerClient.legacyArguments
            ]
        )
    }

    func testInitializeFailuresCanRetryWithFallbackInvocation() {
        XCTAssertTrue(
            CodexAppServerClient.canRetryWithNextInvocation(
                after: CodexAppServerError.responseTimedOut(id: CodexAppServerRequestFactory.initializeRequestID)
            )
        )
        XCTAssertTrue(
            CodexAppServerClient.canRetryWithNextInvocation(after: CodexAppServerError.stdinClosed)
        )
        XCTAssertTrue(
            CodexAppServerClient.canRetryWithNextInvocation(
                after: CodexAppServerError.processExitedBeforeInitialize(exitCode: 1)
            )
        )
    }

    func testProcessExitBeforeInitializeIsNotReportedAsATimeout() throws {
        let executable = try makeExecutable(named: "exit-before-init", contents: "#!/bin/sh\nexit 7\n")
        let client = CodexAppServerClient(codexURL: executable, timeout: 2)

        XCTAssertThrowsError(try client.readRateLimits()) { error in
            guard case .processExitedBeforeInitialize(let exitCode) = error as? CodexAppServerError else {
                return XCTFail("expected exit before initialize, got \(error)")
            }
            XCTAssertEqual(exitCode, 7)
        }
    }

    func testRunningProcessInitializeTimeoutStaysATimeout() throws {
        let executable = try makeExecutable(named: "sleep-through-init", contents: "#!/bin/sh\nsleep 30\n")
        let client = CodexAppServerClient(codexURL: executable, timeout: 0.3)

        XCTAssertThrowsError(try client.readRateLimits()) { error in
            guard case .responseTimedOut(let id) = error as? CodexAppServerError else {
                return XCTFail("expected initialize timeout, got \(error)")
            }
            XCTAssertEqual(id, CodexAppServerRequestFactory.initializeRequestID)
        }
    }

    private func makeExecutable(named name: String, contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-app-server-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
        }
        return url
    }

    func testRateLimitReadFailuresDoNotRetryWithFallbackInvocation() {
        XCTAssertFalse(
            CodexAppServerClient.canRetryWithNextInvocation(
                after: CodexAppServerError.responseTimedOut(id: CodexAppServerRequestFactory.rateLimitReadRequestID)
            )
        )
        XCTAssertFalse(
            CodexAppServerClient.canRetryWithNextInvocation(
                after: CodexAppServerError.rpcError(id: CodexAppServerRequestFactory.initializeRequestID, message: "method changed")
            )
        )
    }

    func testUnsupportedProxyAuthRefreshCanRetryWithLegacyInvocation() {
        XCTAssertTrue(
            CodexAppServerClient.canRetryWithNextInvocation(
                after: CodexAppServerError.rpcError(
                    id: CodexAppServerRequestFactory.chatGPTAuthTokensRefreshRequestID,
                    message: "Invalid request: unknown variant `account/chatgptAuthTokens/refresh`"
                )
            )
        )
    }
}
