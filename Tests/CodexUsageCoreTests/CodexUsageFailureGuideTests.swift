import XCTest
@testable import CodexUsageCore

final class CodexUsageFailureGuideTests: XCTestCase {
    func testMissingCodexCLIGuideIncludesCheckedPathsAndDoctorCommand() {
        let guide = CodexUsageFailureGuide()
        let message = guide.message(
            for: CodexAppServerError.codexBinaryNotFound(["/Applications/Codex.app/Contents/Resources/codex"]),
            context: .status
        )

        XCTAssertTrue(message.contains("codex-usage status failed"))
        XCTAssertTrue(message.contains("CODEX_CLI_PATH"))
        XCTAssertTrue(message.contains("/Applications/Codex.app/Contents/Resources/codex"))
        XCTAssertTrue(message.contains("codex-usage doctor"))
    }

    func testAuthRPCGuideAvoidsAuthFileInspection() {
        let guide = CodexUsageFailureGuide()
        let message = guide.message(
            for: CodexAppServerError.rpcError(id: 2, message: "unauthorized"),
            context: .status
        )

        XCTAssertTrue(message.contains("Open Codex and sign in again"))
        XCTAssertTrue(message.contains("without inspecting ~/.codex/auth.json"))
        XCTAssertTrue(message.contains("codex-usage doctor"))
    }

    func testDoctorFailureFallsBackToCodexStatusInstruction() {
        let guide = CodexUsageFailureGuide()
        let message = guide.message(
            for: CodexAppServerError.responseTimedOut(id: 1),
            context: .doctor
        )

        XCTAssertTrue(message.contains("codex-usage doctor failed"))
        XCTAssertTrue(message.contains("fall back to Codex `/status`"))
    }

    func testInvalidJSONDescriptionRedactsRawLineAndGuideExplainsProtocolChange() {
        let error = CodexAppServerError.invalidJSONLine("{\"access_token\":\"secret\"}")
        XCTAssertFalse(error.localizedDescription.contains("secret"))

        let guide = CodexUsageFailureGuide()
        let message = guide.message(for: error, context: .status)

        XCTAssertTrue(message.contains("protocol may have changed"))
        XCTAssertTrue(message.contains("Do not paste auth tokens or raw app-server payloads"))
        XCTAssertFalse(message.contains("secret"))
    }

    func testDecodingErrorGuideExplainsSchemaChange() {
        struct Empty: Decodable {
            let value: String
        }

        let decodingError: Error
        do {
            _ = try JSONDecoder().decode(Empty.self, from: Data("{}".utf8))
            XCTFail("Expected a decoding error")
            return
        } catch let caughtError {
            decodingError = caughtError
        }

        let message = CodexUsageFailureGuide().message(for: decodingError, context: .status)

        XCTAssertTrue(message.contains("schema may have changed"))
        XCTAssertTrue(message.contains("codex-usage doctor"))
    }
}
