import Foundation

@objc(MacDogPrivilegedHelperXPCProtocol)
public protocol MacDogPrivilegedHelperXPCProtocol {
    func handleRequest(_ requestData: NSData, withReply reply: @escaping (NSData) -> Void)
}

public enum PrivilegedHelperJSONCodec {
    public static func encode(_ request: PrivilegedHelperRequest) throws -> Data {
        try JSONEncoder().encode(request)
    }

    public static func decodeRequest(_ data: Data) throws -> PrivilegedHelperRequest {
        try JSONDecoder().decode(PrivilegedHelperRequest.self, from: data)
    }

    public static func encode(_ response: PrivilegedHelperResponse) throws -> Data {
        try JSONEncoder().encode(response)
    }

    public static func decodeResponse(_ data: Data) throws -> PrivilegedHelperResponse {
        try JSONDecoder().decode(PrivilegedHelperResponse.self, from: data)
    }
}

public final class MacDogPrivilegedHelperXPCService: NSObject, MacDogPrivilegedHelperXPCProtocol {
    private let responder: (PrivilegedHelperRequest) -> PrivilegedHelperResponse

    public init(responder: @escaping (PrivilegedHelperRequest) -> PrivilegedHelperResponse) {
        self.responder = responder
    }

    public convenience init<Runner: PrivilegedHelperCommandRunning & Sendable>(
        handler: PrivilegedHelperCommandHandler<Runner>
    ) {
        self.init(responder: handler.handle)
    }

    public func handleRequest(_ requestData: NSData, withReply reply: @escaping (NSData) -> Void) {
        let response: PrivilegedHelperResponse

        do {
            response = responder(try PrivilegedHelperJSONCodec.decodeRequest(requestData as Data))
        } catch {
            response = PrivilegedHelperResponse(
                status: .failed,
                errorMessage: "helper request decode 실패: \(error.localizedDescription)"
            )
        }

        do {
            reply(try PrivilegedHelperJSONCodec.encode(response) as NSData)
        } catch {
            let fallback = #"{"status":"failed","errorMessage":"helper response encode 실패"}"#
            reply(NSData(data: Data(fallback.utf8)))
        }
    }
}
