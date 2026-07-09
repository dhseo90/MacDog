import XCTest
@testable import CodexUsageCore

final class CodexAppServerClientTests: XCTestCase {
    func testResolverPrefersCurrentChatGPTAppBundleCLI() {
        XCTAssertEqual(
            CodexCLIResolver.defaultCandidates.first,
            "/Applications/ChatGPT.app/Contents/Resources/codex"
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
