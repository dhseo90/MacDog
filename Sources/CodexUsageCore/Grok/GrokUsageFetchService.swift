import Foundation

public protocol GrokBillingTransporting {
    func data(for request: URLRequest) throws -> Data
}

public struct GrokUsageFetchService {
    public static let defaultBillingURL = URL(string: "https://cli-chat-proxy.grok.com/v1/billing?format=credits")!

    private let store: GrokUsageCacheStore
    private let tokenProvider: GrokLocalAuthTokenProvider
    private let transport: any GrokBillingTransporting
    private let billingURL: URL
    private let timeout: TimeInterval

    public init(
        store: GrokUsageCacheStore = GrokUsageCacheStore(),
        tokenProvider: GrokLocalAuthTokenProvider = GrokLocalAuthTokenProvider(),
        transport: any GrokBillingTransporting,
        billingURL: URL = GrokUsageFetchService.defaultBillingURL,
        timeout: TimeInterval = 15
    ) {
        self.store = store
        self.tokenProvider = tokenProvider
        self.transport = transport
        self.billingURL = billingURL
        self.timeout = timeout
    }

    public func writeCache() throws -> GrokUsageIngestResult {
        let accessToken: String
        do {
            accessToken = try tokenProvider.readAccessToken()
        } catch {
            return try store.recordFailure(code: "auth-unavailable")
        }

        let data: Data
        do {
            data = try transport.data(for: billingRequest(accessToken: accessToken))
        } catch {
            return try store.recordFailure(code: "request-failed")
        }

        do {
            let weekly = try GrokBillingSanitizer.weeklyWindow(from: data)
            return try store.record(weekly)
        } catch let error as GrokBillingSanitizationError {
            return try store.recordFailure(code: error.cacheCode)
        }
    }

    private func billingRequest(accessToken: String) -> URLRequest {
        var request = URLRequest(url: billingURL, timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("grok-shell", forHTTPHeaderField: "x-grok-client-identifier")
        request.setValue("xai-grok-cli", forHTTPHeaderField: "User-Agent")
        return request
    }
}

public struct URLSessionGrokBillingTransport: GrokBillingTransporting {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) throws -> Data {
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
                  (200..<300).contains(response.statusCode) else {
                box.result = .failure(URLError(.badServerResponse))
                return
            }
            box.result = .success(data)
        }
        task.resume()
        semaphore.wait()
        return try box.result.get()
    }
}

private final class ResultBox: @unchecked Sendable {
    var result: Result<Data, Error> = .failure(URLError(.unknown))
}
