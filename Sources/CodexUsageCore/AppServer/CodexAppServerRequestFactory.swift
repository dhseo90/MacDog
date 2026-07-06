import Foundation

struct CodexAppServerRequestFactory {
    static let initializeRequestID = 1
    static let rateLimitReadRequestID = 2
    static let chatGPTAuthTokensRefreshRequestID = 3

    func initializeRequest() throws -> Data {
        try request(
            id: Self.initializeRequestID,
            method: "initialize",
            params: [
                "clientInfo": [
                    "name": "codex-usage",
                    "title": "Codex Usage",
                    "version": "codex-usage-client"
                ],
                "capabilities": [
                    "experimentalApi": true,
                    "requestAttestation": false
                ]
            ]
        )
    }

    func rateLimitReadRequest() throws -> Data {
        try request(id: Self.rateLimitReadRequestID, method: "account/rateLimits/read", params: nil)
    }

    func chatGPTAuthTokensRefreshRequest(previousAccountId: String?) throws -> Data {
        var params: [String: Any] = [
            "reason": "unauthorized"
        ]
        if let previousAccountId {
            params["previousAccountId"] = previousAccountId
        }
        return try request(
            id: Self.chatGPTAuthTokensRefreshRequestID,
            method: "account/chatgptAuthTokens/refresh",
            params: params
        )
    }

    private func request(id: Int, method: String, params: Any?) throws -> Data {
        var payload: [String: Any] = [
            "id": id,
            "method": method
        ]
        if let params {
            payload["params"] = params
        }

        var data = try JSONSerialization.data(withJSONObject: payload)
        data.append(0x0A)
        return data
    }
}
