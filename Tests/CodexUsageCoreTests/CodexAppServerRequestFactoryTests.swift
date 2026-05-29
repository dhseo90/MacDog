import XCTest
@testable import CodexUsageCore

final class CodexAppServerRequestFactoryTests: XCTestCase {
    func testInitializeRequestKeepsAppServerContract() throws {
        let request = try CodexAppServerRequestFactory().initializeRequest()
        let object = try jsonObject(fromLineRequest: request)

        XCTAssertEqual(object["id"] as? Int, 1)
        XCTAssertEqual(object["method"] as? String, "initialize")

        let params = try XCTUnwrap(object["params"] as? [String: Any])
        let clientInfo = try XCTUnwrap(params["clientInfo"] as? [String: Any])
        XCTAssertEqual(clientInfo["name"] as? String, "codex-usage")
        XCTAssertEqual(clientInfo["title"] as? String, "Codex Usage")
        XCTAssertEqual(clientInfo["version"] as? String, "1.0.0")

        let capabilities = try XCTUnwrap(params["capabilities"] as? [String: Any])
        XCTAssertEqual(capabilities["experimentalApi"] as? Bool, true)
        XCTAssertEqual(capabilities["requestAttestation"] as? Bool, false)
    }

    func testRateLimitReadRequestKeepsAppServerContract() throws {
        let request = try CodexAppServerRequestFactory().rateLimitReadRequest()
        let object = try jsonObject(fromLineRequest: request)

        XCTAssertEqual(object["id"] as? Int, 2)
        XCTAssertEqual(object["method"] as? String, "account/rateLimits/read")
        XCTAssertNil(object["params"])
    }

    func testRequestsAreNewlineDelimitedAndDoNotContainAuthMaterial() throws {
        let requests = [
            try CodexAppServerRequestFactory().initializeRequest(),
            try CodexAppServerRequestFactory().rateLimitReadRequest()
        ]

        for request in requests {
            XCTAssertEqual(request.last, 0x0A)
            let text = String(decoding: request, as: UTF8.self)
            XCTAssertFalse(text.localizedCaseInsensitiveContains("access_token"))
            XCTAssertFalse(text.localizedCaseInsensitiveContains("refresh_token"))
            XCTAssertFalse(text.localizedCaseInsensitiveContains("cookie"))
            XCTAssertFalse(text.localizedCaseInsensitiveContains("authorization"))
        }
    }

    private func jsonObject(fromLineRequest request: Data) throws -> [String: Any] {
        XCTAssertEqual(request.last, 0x0A)
        let body = request.dropLast()
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(body)) as? [String: Any])
    }
}
