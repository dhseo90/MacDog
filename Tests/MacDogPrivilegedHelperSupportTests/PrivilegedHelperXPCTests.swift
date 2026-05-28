import XCTest
@testable import MacDogPrivilegedHelperSupport

final class PrivilegedHelperXPCTests: XCTestCase {
    func testXPCServiceDecodesRequestAndEncodesResponse() throws {
        let service = MacDogPrivilegedHelperXPCService { request in
            XCTAssertEqual(request, PrivilegedHelperRequest(command: .readSleepDisabled))
            return PrivilegedHelperResponse(status: .success, sleepDisabled: true)
        }

        let reply = try send(
            PrivilegedHelperRequest(command: .readSleepDisabled),
            to: service
        )

        XCTAssertEqual(reply.status, .success)
        XCTAssertEqual(reply.sleepDisabled, true)
    }

    func testXPCServiceReturnsFailureForInvalidRequestPayload() throws {
        let service = MacDogPrivilegedHelperXPCService { _ in
            XCTFail("Invalid request should not reach responder")
            return PrivilegedHelperResponse(status: .success)
        }

        let expectation = expectation(description: "reply")
        var responseData: Data?
        service.handleRequest(NSData(data: Data("not-json".utf8))) { data in
            responseData = data as Data
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)

        let response = try PrivilegedHelperJSONCodec.decodeResponse(XCTUnwrap(responseData))
        XCTAssertEqual(response.status, .failed)
        XCTAssertTrue(response.errorMessage?.contains("decode 실패") == true)
    }

    private func send(
        _ request: PrivilegedHelperRequest,
        to service: MacDogPrivilegedHelperXPCProtocol
    ) throws -> PrivilegedHelperResponse {
        let expectation = expectation(description: "reply")
        var responseData: Data?
        service.handleRequest(try PrivilegedHelperJSONCodec.encode(request) as NSData) { data in
            responseData = data as Data
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
        return try PrivilegedHelperJSONCodec.decodeResponse(XCTUnwrap(responseData))
    }
}
