import Foundation

public protocol GrokBillingTransporting {
    func data(for request: URLRequest) throws -> Data
}

public enum GrokBillingTransportError: Error, Equatable, Sendable {
    case unauthorized
    case failed
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
            return try store.recordFailure(code: Self.failureCode(for: error))
        }

        switch fetchWeekly(using: accessToken) {
        case .stored(let weekly):
            return try store.record(weekly)
        case .unauthorized:
            let retriedToken: String
            do {
                retriedToken = try tokenProvider.readAccessToken(rejecting: accessToken)
            } catch {
                return try store.recordFailure(code: Self.failureCode(for: error))
            }
            switch fetchWeekly(using: retriedToken) {
            case .stored(let weekly):
                return try store.record(weekly)
            case .unauthorized, .failed:
                return try store.recordFailure(code: "request-failed")
            case .invalid(let code):
                return try store.recordFailure(code: code)
            }
        case .failed:
            return try store.recordFailure(code: "request-failed")
        case .invalid(let code):
            return try store.recordFailure(code: code)
        }
    }

    private enum FetchOutcome {
        case stored(GrokUsageWeeklyWindow)
        case unauthorized
        case failed
        case invalid(String)
    }

    private func fetchWeekly(using accessToken: String) -> FetchOutcome {
        let data: Data
        do {
            data = try transport.data(for: billingRequest(accessToken: accessToken))
        } catch GrokBillingTransportError.unauthorized {
            return .unauthorized
        } catch {
            return .failed
        }

        do {
            return .stored(try GrokBillingSanitizer.weeklyWindow(from: data))
        } catch let error as GrokBillingSanitizationError {
            return .invalid(error.cacheCode)
        } catch {
            return .invalid("billing-decode-failed")
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

    static func failureCode(for error: Error) -> String {
        switch error as? GrokLocalAuthTokenProviderError {
        case .expiredAccessToken:
            return "auth-expired"
        case .refreshFailed:
            return "auth-refresh-failed"
        case .noCredentialsFound, .missingAccessToken, .none:
            return "auth-unavailable"
        }
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
            guard let http = response as? HTTPURLResponse else {
                box.result = .failure(GrokBillingTransportError.failed)
                return
            }
            if http.statusCode == 401 || http.statusCode == 403 {
                box.result = .failure(GrokBillingTransportError.unauthorized)
                return
            }
            guard let data, (200..<300).contains(http.statusCode) else {
                box.result = .failure(GrokBillingTransportError.failed)
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
