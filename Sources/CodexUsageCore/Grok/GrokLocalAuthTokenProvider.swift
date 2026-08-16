import Foundation

public enum GrokLocalAuthTokenProviderError: LocalizedError, Equatable, Sendable {
    case noCredentialsFound
    case missingAccessToken

    public var errorDescription: String? {
        switch self {
        case .noCredentialsFound:
            return "Grok auth store was unavailable for weekly usage lookup."
        case .missingAccessToken:
            return "Grok auth store did not contain an access token for weekly usage lookup."
        }
    }
}

public struct GrokLocalAuthTokenProvider {
    private let authFileURLs: [URL]
    private let fileManager: FileManager

    public init(
        authFileURLs: [URL] = Self.defaultAuthFileURLs(),
        fileManager: FileManager = .default
    ) {
        self.authFileURLs = authFileURLs
        self.fileManager = fileManager
    }

    public static func defaultAuthFileURLs() -> [URL] {
        var urls: [URL] = []
        if let grokHome = ProcessInfo.processInfo.environment["GROK_HOME"], !grokHome.isEmpty {
            urls.append(
                URL(fileURLWithPath: grokHome, isDirectory: true).appendingPathComponent("auth.json")
            )
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        urls.append(
            home
                .appendingPathComponent(".grok", isDirectory: true)
                .appendingPathComponent("auth.json")
        )
        return urls
    }

    public func readAccessToken() throws -> String {
        for url in authFileURLs where fileManager.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            if let token = Self.accessToken(from: data), !token.isEmpty {
                return token
            }
        }
        throw GrokLocalAuthTokenProviderError.noCredentialsFound
    }

    static func accessToken(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let token = object["access_token"] as? String, !token.isEmpty {
            return token
        }
        if let tokens = object["tokens"] as? [String: Any],
           let token = tokens["access_token"] as? String,
           !token.isEmpty {
            return token
        }
        if let signIn = object["https://accounts.x.ai/sign-in"] as? [String: Any],
           let token = signIn["key"] as? String,
           !token.isEmpty {
            return token
        }
        return nil
    }
}
