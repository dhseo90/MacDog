import Foundation

public enum CodexUsageFieldInventoryError: Error, Equatable {
    case invalidEnvelope
    case missingResult
}

public struct CodexUsageBucketFieldInventory: Equatable, Sendable {
    public let key: String
    public let limitId: String
    public let fields: [String]
    public let primaryFields: [String]
    public let secondaryFields: [String]
    public let creditsFields: [String]

    public init(
        key: String,
        limitId: String,
        fields: [String],
        primaryFields: [String],
        secondaryFields: [String],
        creditsFields: [String]
    ) {
        self.key = key
        self.limitId = limitId
        self.fields = fields
        self.primaryFields = primaryFields
        self.secondaryFields = secondaryFields
        self.creditsFields = creditsFields
    }
}

public struct CodexUsageFieldInventory: Equatable, Sendable {
    public let topLevelFields: [String]
    public let buckets: [CodexUsageBucketFieldInventory]

    public init(topLevelFields: [String], buckets: [CodexUsageBucketFieldInventory]) {
        self.topLevelFields = topLevelFields
        self.buckets = buckets
    }

    public var redactedSummaryLines: [String] {
        var lines: [String] = []
        for bucket in buckets {
            let bucketName = CodexUsageSensitiveNameRedactor.redactedBucketIdentifier(
                key: bucket.key,
                limitId: bucket.limitId
            )
            lines.append("bucket: \(bucketName)")
            lines.append("fields: \(bucket.fields.joined(separator: ", "))")
            lines.append("primary fields: \(bucket.primaryFields.joined(separator: ", "))")
            lines.append("secondary fields: \(bucket.secondaryFields.joined(separator: ", "))")
            lines.append("credits fields: \(bucket.creditsFields.joined(separator: ", "))")
        }
        return lines
    }

    public static func make(fromJSONRPCResponseData data: Data) throws -> CodexUsageFieldInventory {
        guard
            let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let result = envelope["result"] as? [String: Any]
        else {
            if let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               envelope["result"] == nil {
                throw CodexUsageFieldInventoryError.missingResult
            }
            throw CodexUsageFieldInventoryError.invalidEnvelope
        }

        return make(fromRateLimitsObject: result)
    }

    public static func make(fromRateLimitsObject result: [String: Any]) -> CodexUsageFieldInventory {
        let topLevelFields = result.keys.map(CodexUsageSensitiveNameRedactor.redacted).sorted()
        let bucketSource: [String: Any]
        if let bucketsByLimitId = result["rateLimitsByLimitId"] as? [String: Any] {
            bucketSource = bucketsByLimitId
        } else {
            let legacyBucket = result["rateLimits"] as? [String: Any]
            let legacyLimitId = (legacyBucket?["limitId"] as? String) ?? "codex"
            bucketSource = [legacyLimitId: legacyBucket as Any]
        }

        var buckets: [CodexUsageBucketFieldInventory] = []
        for key in bucketSource.keys.sorted() {
            guard let rawBucket = bucketSource[key] as? [String: Any] else { continue }

            let sanitizedKey = key
            let limitId = (rawBucket["limitId"] as? String) ?? key
            let fields = rawBucket.keys.map(CodexUsageSensitiveNameRedactor.redacted).sorted()
            let primary = (rawBucket["primary"] as? [String: Any]) ?? [:]
            let secondary = (rawBucket["secondary"] as? [String: Any]) ?? [:]
            let credits = (rawBucket["credits"] as? [String: Any]) ?? [:]

            buckets.append(
                CodexUsageBucketFieldInventory(
                    key: sanitizedKey,
                    limitId: limitId,
                    fields: fields,
                    primaryFields: primary.keys.map(CodexUsageSensitiveNameRedactor.redacted).sorted(),
                    secondaryFields: secondary.keys.map(CodexUsageSensitiveNameRedactor.redacted).sorted(),
                    creditsFields: credits.keys.map(CodexUsageSensitiveNameRedactor.redacted).sorted()
                )
            )
        }

        return CodexUsageFieldInventory(
            topLevelFields: topLevelFields,
            buckets: buckets
        )
    }
}

enum CodexUsageSensitiveNameRedactor {
    static let placeholder = "<redacted-sensitive-field>"

    private static let redactedFragments: Set<String> = [
        "access_token",
        "refresh_token",
        "id_token",
        "auth_token",
        "authtoken",
        "authorization",
        "cookie",
        "session",
        "client_secret",
        "clientsecret",
        "api_key",
        "apikey",
        "auth_header",
        "accesstoken",
        "refreshtoken",
        "idtoken",
        "token",
        "authheader"
    ]

    static func redacted(_ name: String) -> String {
        shouldRedact(name) ? placeholder : name
    }

    static func redactedBucketIdentifier(key: String, limitId: String) -> String {
        shouldRedact(key) || shouldRedact(limitId) ? placeholder : key
    }

    private static func shouldRedact(_ name: String) -> Bool {
        let normalized = name
            .replacingOccurrences(of: "-", with: "_")
            .lowercased()
        return redactedFragments.contains(where: normalized.contains)
    }
}
