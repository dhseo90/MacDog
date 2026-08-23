import Foundation

public enum GrokLocalAuthTokenProviderError: LocalizedError, Equatable, Sendable {
    case noCredentialsFound
    case missingAccessToken
    case expiredAccessToken
    case refreshFailed

    public var errorDescription: String? {
        switch self {
        case .noCredentialsFound:
            return "Grok auth store was unavailable for weekly usage lookup."
        case .missingAccessToken:
            return "Grok auth store did not contain an access token for weekly usage lookup."
        case .expiredAccessToken:
            return "Grok auth store access token expired for weekly usage lookup."
        case .refreshFailed:
            return "Grok auth token refresh failed for weekly usage lookup."
        }
    }
}

public struct GrokLocalAuthTokenProvider {
    public static let earlyInvalidationSeconds: TimeInterval = 300
    public static let fallbackTokenTTLSeconds: TimeInterval = 30 * 24 * 60 * 60
    public static let defaultLockTimeout: TimeInterval = 2

    private let authFileURLs: [URL]
    private let fileManager: FileManager
    private let dateProvider: () -> Date
    private let lockTimeout: TimeInterval
    private let lock: any GrokAuthFileLocking
    private let refresher: (any GrokOIDCRefreshing)?

    public init(
        authFileURLs: [URL] = Self.defaultAuthFileURLs(),
        fileManager: FileManager = .default,
        dateProvider: @escaping () -> Date = Date.init,
        lockTimeout: TimeInterval = Self.defaultLockTimeout,
        lock: any GrokAuthFileLocking = GrokAuthFileLock(),
        refresher: (any GrokOIDCRefreshing)? = URLSessionGrokOIDCRefresher()
    ) {
        self.authFileURLs = authFileURLs
        self.fileManager = fileManager
        self.dateProvider = dateProvider
        self.lockTimeout = lockTimeout
        self.lock = lock
        self.refresher = refresher
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
        try readAccessToken(rejecting: nil)
    }

    public func readAccessToken(rejecting rejectedToken: String?) throws -> String {
        guard let authURL = firstExistingAuthURL() else {
            throw GrokLocalAuthTokenProviderError.noCredentialsFound
        }
        if let token = try usableAccessToken(at: authURL), token != rejectedToken {
            return token
        }

        let refreshed = try lock.withExclusiveLock(
            adjacentTo: authURL,
            timeout: lockTimeout
        ) {
            try refreshUnderLock(authURL: authURL, rejecting: rejectedToken)
        }
        if let token = refreshed {
            return token
        }

        if let token = try usableAccessToken(at: authURL), token != rejectedToken {
            return token
        }
        throw GrokLocalAuthTokenProviderError.expiredAccessToken
    }

    private func firstExistingAuthURL() -> URL? {
        authFileURLs.first { fileManager.fileExists(atPath: $0.path) }
    }

    private func usableAccessToken(at authURL: URL) throws -> String? {
        let store = try readStore(at: authURL)
        return Self.usableAccessToken(from: store, now: dateProvider())
    }

    private func refreshUnderLock(authURL: URL, rejecting rejectedToken: String?) throws -> String {
        let store = try readStore(at: authURL)
        let now = dateProvider()
        if let token = Self.usableAccessToken(from: store, now: now), token != rejectedToken {
            return token
        }
        guard let refresher else {
            throw GrokLocalAuthTokenProviderError.expiredAccessToken
        }
        guard let target = Self.refreshTarget(from: store) else {
            throw GrokLocalAuthTokenProviderError.expiredAccessToken
        }

        let tokens: GrokOIDCRefreshTokens
        do {
            tokens = try refresher.refresh(target.request)
        } catch {
            throw GrokLocalAuthTokenProviderError.refreshFailed
        }
        guard !tokens.accessToken.isEmpty else {
            throw GrokLocalAuthTokenProviderError.refreshFailed
        }

        let expiresAt = tokens.expiresIn.map { now.addingTimeInterval($0) }
        let merged = Self.mergeRefreshedEntry(
            store: store,
            scope: target.scope,
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken ?? target.request.refreshToken,
            expiresAt: expiresAt,
            now: now
        )
        try atomicWrite(merged, to: authURL)
        return tokens.accessToken
    }

    private func readStore(at authURL: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: authURL)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GrokLocalAuthTokenProviderError.noCredentialsFound
        }
        return object
    }

    private func atomicWrite(_ object: [String: Any], to url: URL) throws {
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys]
        )
        let tmp = url.deletingLastPathComponent().appendingPathComponent(
            "auth.json.\(ProcessInfo.processInfo.processIdentifier).\(UUID().uuidString).tmp"
        )
        do {
            try data.write(to: tmp, options: .withoutOverwriting)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tmp.path)
            _ = try fileManager.replaceItemAt(url, withItemAt: tmp)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            try? fileManager.removeItem(at: tmp)
            throw error
        }
    }

    static func accessToken(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return usableAccessToken(from: object, now: Date())
            ?? rawAccessToken(from: object)?.token
    }

    private static func usableAccessToken(from object: [String: Any], now: Date) -> String? {
        guard let resolved = rawAccessToken(from: object) else {
            return nil
        }
        if isExpired(resolved.entry, now: now) {
            return nil
        }
        return resolved.token
    }

    private static func rawAccessToken(from object: [String: Any]) -> ResolvedToken? {
        if let token = object["access_token"] as? String, !token.isEmpty {
            return ResolvedToken(scope: "access_token", token: token, entry: object)
        }
        if let tokens = object["tokens"] as? [String: Any],
           let token = tokens["access_token"] as? String,
           !token.isEmpty {
            return ResolvedToken(scope: "tokens", token: token, entry: tokens)
        }
        return tokenFromIssuerEntries(object)
    }

    private static let issuerPrefixes = [
        "https://accounts.x.ai",
        "https://auth.x.ai"
    ]

    private static func tokenFromIssuerEntries(_ object: [String: Any]) -> ResolvedToken? {
        for (key, value) in object {
            guard issuerPrefixes.contains(where: { prefix in
                key == prefix || key.hasPrefix(prefix + "/") || key.hasPrefix(prefix + "::")
            }) else {
                continue
            }
            guard let entry = value as? [String: Any] else { continue }
            if let token = entry["key"] as? String, !token.isEmpty {
                return ResolvedToken(scope: key, token: token, entry: entry)
            }
            if let token = entry["access_token"] as? String, !token.isEmpty {
                return ResolvedToken(scope: key, token: token, entry: entry)
            }
        }
        return nil
    }

    private static func refreshTarget(from object: [String: Any]) -> RefreshTarget? {
        guard let resolved = tokenFromIssuerEntries(object) ?? rawAccessToken(from: object) else {
            return nil
        }
        let entry = resolved.entry
        guard let refreshToken = stringValue(entry["refresh_token"]), !refreshToken.isEmpty else {
            return nil
        }
        let clientID = stringValue(entry["oidc_client_id"])
            ?? clientID(fromScope: resolved.scope)
        let issuer = stringValue(entry["oidc_issuer"])
            ?? issuer(fromScope: resolved.scope)
        guard let clientID, !clientID.isEmpty, let issuer, !issuer.isEmpty else {
            return nil
        }
        return RefreshTarget(
            scope: resolved.scope,
            request: GrokOIDCRefreshRequest(
                refreshToken: refreshToken,
                clientID: clientID,
                issuer: issuer,
                principalType: stringValue(entry["principal_type"]),
                principalID: stringValue(entry["principal_id"])
            )
        )
    }

    private static func clientID(fromScope scope: String) -> String? {
        guard let separator = scope.range(of: "::") else {
            return nil
        }
        let value = String(scope[separator.upperBound...])
        return value.isEmpty ? nil : value
    }

    private static func issuer(fromScope scope: String) -> String? {
        if scope.hasPrefix("https://auth.x.ai") {
            return "https://auth.x.ai"
        }
        if scope.hasPrefix("https://accounts.x.ai") {
            return "https://accounts.x.ai"
        }
        return nil
    }

    private static func isExpired(_ entry: [String: Any], now: Date) -> Bool {
        if let expiresAt = parseTimestamp(entry["expires_at"]) {
            return now >= expiresAt.addingTimeInterval(-earlyInvalidationSeconds)
        }
        if let createTime = parseTimestamp(entry["create_time"]) {
            return now >= createTime.addingTimeInterval(fallbackTokenTTLSeconds - earlyInvalidationSeconds)
        }
        return false
    }

    private static func parseTimestamp(_ value: Any?) -> Date? {
        guard let raw = value as? String, !raw.isEmpty else {
            return nil
        }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: raw) {
            return date
        }
        let basic = ISO8601DateFormatter()
        basic.formatOptions = [.withInternetDateTime]
        if let date = basic.date(from: raw) {
            return date
        }
        return trimmedFractionalISO8601(raw).flatMap { trimmed in
            fractional.date(from: trimmed) ?? basic.date(from: trimmed)
        }
    }

    private static func trimmedFractionalISO8601(_ raw: String) -> String? {
        guard let dot = raw.firstIndex(of: "."),
              let timezone = raw.lastIndex(where: { $0 == "+" || $0 == "-" || $0 == "Z" }),
              dot < timezone else {
            return nil
        }
        let fraction = raw[raw.index(after: dot)..<timezone]
        let digits = fraction.prefix { $0.isNumber }
        guard digits.count > 3 else {
            return nil
        }
        return String(raw[..<raw.index(after: dot)]) + String(digits.prefix(3)) + String(raw[timezone...])
    }

    private static func mergeRefreshedEntry(
        store: [String: Any],
        scope: String,
        accessToken: String,
        refreshToken: String,
        expiresAt: Date?,
        now: Date
    ) -> [String: Any] {
        var store = store
        var entry = store[scope] as? [String: Any] ?? [:]
        entry["key"] = accessToken
        entry["refresh_token"] = refreshToken
        entry["create_time"] = formatTimestamp(now)
        if let expiresAt {
            entry["expires_at"] = formatTimestamp(expiresAt)
        }
        store[scope] = entry
        return store
    }

    private static func formatTimestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func stringValue(_ value: Any?) -> String? {
        guard let value = value as? String, !value.isEmpty else {
            return nil
        }
        return value
    }
}

private struct ResolvedToken {
    let scope: String
    let token: String
    let entry: [String: Any]
}

private struct RefreshTarget {
    let scope: String
    let request: GrokOIDCRefreshRequest
}
