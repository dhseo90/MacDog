import Foundation

public protocol CodexResetCreditDetailsFetching {
    func fetch(
        accessToken: String,
        accountId: String?,
        timeout: TimeInterval
    ) throws -> RateLimitResetCreditsSummary
}

public enum CodexResetCreditDetailsError: LocalizedError, Equatable, Sendable {
    case missingAccessToken
    case invalidHTTPResponse
    case httpStatus(Int)

    public var errorDescription: String? {
        switch self {
        case .missingAccessToken:
            return "reset credit detail request requires an in-memory Codex access token."
        case .invalidHTTPResponse:
            return "reset credit detail request returned an invalid HTTP response."
        case .httpStatus(let statusCode):
            return "reset credit detail request failed (HTTP \(statusCode))."
        }
    }
}

public struct CodexResetCreditDetailsClient: CodexResetCreditDetailsFetching {
    public typealias DataLoader = (URLRequest) throws -> (Data, HTTPURLResponse)

    public static let defaultEndpointURL = URL(
        string: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits"
    )!

    private let endpointURL: URL
    private let dataLoader: DataLoader

    public init(
        endpointURL: URL = Self.defaultEndpointURL,
        dataLoader: @escaping DataLoader = Self.urlSessionDataLoader
    ) {
        self.endpointURL = endpointURL
        self.dataLoader = dataLoader
    }

    public func fetch(
        accessToken: String,
        accountId: String?,
        timeout: TimeInterval = 15
    ) throws -> RateLimitResetCreditsSummary {
        guard !accessToken.isEmpty else {
            throw CodexResetCreditDetailsError.missingAccessToken
        }

        var request = URLRequest(url: endpointURL, timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
            forHTTPHeaderField: "User-Agent"
        )
        if let accountId, !accountId.isEmpty {
            request.setValue(accountId, forHTTPHeaderField: "ChatGPT-Account-Id")
        }

        let (data, response) = try dataLoader(request)
        guard (200..<300).contains(response.statusCode) else {
            throw CodexResetCreditDetailsError.httpStatus(response.statusCode)
        }

        return try JSONDecoder().decode(RateLimitResetCreditsSummary.self, from: data)
    }

    public static func urlSessionDataLoader(_ request: URLRequest) throws -> (Data, HTTPURLResponse) {
        let semaphore = DispatchSemaphore(value: 0)
        let resultBox = URLSessionResultBox()

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }

            if let error {
                resultBox.result = .failure(error)
                return
            }
            guard let data,
                  let response = response as? HTTPURLResponse
            else {
                resultBox.result = .failure(CodexResetCreditDetailsError.invalidHTTPResponse)
                return
            }
            resultBox.result = .success((data, response))
        }
        task.resume()
        semaphore.wait()
        return try resultBox.result.get()
    }
}

private final class URLSessionResultBox: @unchecked Sendable {
    var result: Result<(Data, HTTPURLResponse), Error> = .failure(CodexResetCreditDetailsError.invalidHTTPResponse)
}
