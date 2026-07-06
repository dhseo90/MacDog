import Foundation

public enum CodexLocalAuthTokenProviderError: LocalizedError, Equatable, Sendable {
    case noCredentialsFound
    case missingAccessToken

    public var errorDescription: String? {
        switch self {
        case .noCredentialsFound:
            return "Codex auth store was unavailable for reset credit expiry lookup."
        case .missingAccessToken:
            return "Codex auth store did not contain an access token for reset credit expiry lookup."
        }
    }
}

public struct CodexLocalAuthTokenProvider {
    public typealias KeychainReader = () throws -> Data?
    public typealias TokenRefresher = (String) throws -> String

    private static let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"

    private let authFileURLs: [URL]
    private let keychainReader: KeychainReader
    private let tokenRefresher: TokenRefresher?

    public init(
        authFileURLs: [URL] = Self.defaultAuthFileURLs(),
        keychainReader: @escaping KeychainReader = Self.readCodexKeychainAuth,
        tokenRefresher: TokenRefresher? = Self.refreshAccessToken
    ) {
        self.authFileURLs = authFileURLs
        self.keychainReader = keychainReader
        self.tokenRefresher = tokenRefresher
    }

    public func readTokens() throws -> ChatGPTAuthTokensRefreshResponse {
        let auth = try readAuthStore()
        guard let tokens = auth.tokens,
              let storedAccessToken = tokens.accessToken,
              !storedAccessToken.isEmpty
        else {
            throw CodexLocalAuthTokenProviderError.missingAccessToken
        }

        let accessToken: String
        if let refreshToken = tokens.refreshToken,
           !refreshToken.isEmpty,
           let tokenRefresher,
           let refreshed = try? tokenRefresher(refreshToken),
           !refreshed.isEmpty {
            accessToken = refreshed
        } else {
            accessToken = storedAccessToken
        }

        return ChatGPTAuthTokensRefreshResponse(
            accessToken: accessToken,
            chatgptAccountId: tokens.accountId ?? "",
            chatgptPlanType: nil
        )
    }

    public static func defaultAuthFileURLs() -> [URL] {
        var urls: [URL] = []
        let environment = ProcessInfo.processInfo.environment
        if let codexHome = environment["CODEX_HOME"], !codexHome.isEmpty {
            urls.append(URL(fileURLWithPath: codexHome, isDirectory: true).appendingPathComponent("auth.json"))
        }

        let home = FileManager.default.homeDirectoryForCurrentUser
        urls.append(
            home
                .appendingPathComponent(".config", isDirectory: true)
                .appendingPathComponent("codex", isDirectory: true)
                .appendingPathComponent("auth.json")
        )
        urls.append(
            home
                .appendingPathComponent(".codex", isDirectory: true)
                .appendingPathComponent("auth.json")
        )
        return urls
    }

    private func readAuthStore() throws -> CodexAuthStore {
        for url in authFileURLs where FileManager.default.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            if let auth = try? JSONDecoder().decode(CodexAuthStore.self, from: data) {
                return auth
            }
        }

        if let keychainData = try keychainReader(),
           let auth = try? JSONDecoder().decode(CodexAuthStore.self, from: keychainData) {
            return auth
        }

        throw CodexLocalAuthTokenProviderError.noCredentialsFound
    }

    public static func readCodexKeychainAuth() throws -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Codex Auth", "-w"]

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice

        try process.run()
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0, !data.isEmpty else {
            return nil
        }
        return data
    }

    public static func refreshAccessToken(refreshToken: String) throws -> String {
        var request = URLRequest(url: URL(string: "https://auth.openai.com/oauth/token")!, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncodedBody([
            "grant_type": "refresh_token",
            "client_id": clientID,
            "refresh_token": refreshToken
        ])

        let semaphore = DispatchSemaphore(value: 0)
        let resultBox = TokenRefreshResultBox()
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }

            if let error {
                resultBox.result = .failure(error)
                return
            }
            guard let data,
                  let response = response as? HTTPURLResponse,
                  (200..<300).contains(response.statusCode)
            else {
                resultBox.result = .failure(CodexLocalAuthTokenProviderError.missingAccessToken)
                return
            }
            do {
                let decoded = try JSONDecoder().decode(TokenRefreshResponse.self, from: data)
                resultBox.result = .success(decoded.accessToken)
            } catch {
                resultBox.result = .failure(error)
            }
        }
        task.resume()
        semaphore.wait()
        return try resultBox.result.get()
    }

    private static func formEncodedBody(_ fields: [String: String]) -> Data {
        let body = fields
            .map { key, value in
                "\(formEscape(key))=\(formEscape(value))"
            }
            .joined(separator: "&")
        return Data(body.utf8)
    }

    private static func formEscape(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

private struct CodexAuthStore: Decodable {
    let tokens: CodexAuthTokens?
}

private struct CodexAuthTokens: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let accountId: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case accountId = "account_id"
    }
}

private struct TokenRefreshResponse: Decodable {
    let accessToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }
}

private final class TokenRefreshResultBox: @unchecked Sendable {
    var result: Result<String, Error> = .failure(CodexLocalAuthTokenProviderError.missingAccessToken)
}
