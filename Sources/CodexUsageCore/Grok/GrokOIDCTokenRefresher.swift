import Foundation

public struct GrokOIDCRefreshRequest: Equatable, Sendable {
    public let refreshToken: String
    public let clientID: String
    public let issuer: String
    public let principalType: String?
    public let principalID: String?

    public init(
        refreshToken: String,
        clientID: String,
        issuer: String,
        principalType: String? = nil,
        principalID: String? = nil
    ) {
        self.refreshToken = refreshToken
        self.clientID = clientID
        self.issuer = issuer
        self.principalType = principalType
        self.principalID = principalID
    }
}

public struct GrokOIDCRefreshTokens: Equatable, Sendable {
    public let accessToken: String
    public let refreshToken: String?
    public let expiresIn: TimeInterval?

    public init(accessToken: String, refreshToken: String?, expiresIn: TimeInterval?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
    }
}

public protocol GrokOIDCRefreshing: Sendable {
    func refresh(_ request: GrokOIDCRefreshRequest) throws -> GrokOIDCRefreshTokens
}

public struct URLSessionGrokOIDCRefresher: GrokOIDCRefreshing {
    private let session: URLSession
    private let timeout: TimeInterval

    public init(session: URLSession = .shared, timeout: TimeInterval = 15) {
        self.session = session
        self.timeout = timeout
    }

    public func refresh(_ request: GrokOIDCRefreshRequest) throws -> GrokOIDCRefreshTokens {
        let tokenEndpoint = try discoverTokenEndpoint(issuer: request.issuer)
        var urlRequest = URLRequest(url: tokenEndpoint, timeoutInterval: timeout)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var fields = [
            "grant_type": "refresh_token",
            "refresh_token": request.refreshToken,
            "client_id": request.clientID
        ]
        if let principalType = request.principalType, !principalType.isEmpty {
            fields["principal_type"] = principalType
        }
        if let principalID = request.principalID, !principalID.isEmpty {
            fields["principal_id"] = principalID
        }
        urlRequest.httpBody = formEncodedBody(fields)

        let data = try send(urlRequest)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let payload = object as? [String: Any],
              let accessToken = payload["access_token"] as? String,
              !accessToken.isEmpty
        else {
            throw GrokLocalAuthTokenProviderError.refreshFailed
        }
        let refreshToken = payload["refresh_token"] as? String
        let expiresIn: TimeInterval?
        switch payload["expires_in"] {
        case let number as NSNumber:
            expiresIn = number.doubleValue
        case let number as Double:
            expiresIn = number
        case let number as Int:
            expiresIn = TimeInterval(number)
        default:
            expiresIn = nil
        }
        return GrokOIDCRefreshTokens(
            accessToken: accessToken,
            refreshToken: refreshToken?.isEmpty == false ? refreshToken : nil,
            expiresIn: expiresIn
        )
    }

    private func discoverTokenEndpoint(issuer: String) throws -> URL {
        let trimmed = issuer.hasSuffix("/") ? String(issuer.dropLast()) : issuer
        guard let discoveryURL = URL(string: "\(trimmed)/.well-known/openid-configuration") else {
            throw GrokLocalAuthTokenProviderError.refreshFailed
        }
        var request = URLRequest(url: discoveryURL, timeoutInterval: timeout)
        request.httpMethod = "GET"
        let data = try send(request)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let payload = object as? [String: Any],
              let endpoint = payload["token_endpoint"] as? String,
              let url = URL(string: endpoint)
        else {
            throw GrokLocalAuthTokenProviderError.refreshFailed
        }
        return url
    }

    private func send(_ request: URLRequest) throws -> Data {
        let semaphore = DispatchSemaphore(value: 0)
        let box = ResultBox()
        let task = session.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            if let error {
                box.result = .failure(error)
                return
            }
            guard let data,
                  let response = response as? HTTPURLResponse,
                  (200..<300).contains(response.statusCode)
            else {
                box.result = .failure(GrokLocalAuthTokenProviderError.refreshFailed)
                return
            }
            box.result = .success(data)
        }
        task.resume()
        semaphore.wait()
        return try box.result.get()
    }

    private func formEncodedBody(_ fields: [String: String]) -> Data {
        let body = fields
            .map { key, value in
                "\(formEscape(key))=\(formEscape(value))"
            }
            .joined(separator: "&")
        return Data(body.utf8)
    }

    private func formEscape(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

private final class ResultBox: @unchecked Sendable {
    var result: Result<Data, Error> = .failure(GrokLocalAuthTokenProviderError.refreshFailed)
}
