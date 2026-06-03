public struct CodexUsageDoctorFormatter: Sendable {
    public init() {}

    public func bucketInventoryLines(from inventory: CodexUsageFieldInventory) -> [String] {
        guard !inventory.buckets.isEmpty else {
            return ["Buckets: unavailable"]
        }

        var lines = [
            "Buckets: \(inventory.buckets.map(Self.displayName(for:)).joined(separator: ", "))"
        ]

        for bucket in inventory.buckets {
            let bucketName = Self.displayName(for: bucket)
            lines.append("Bucket \(bucketName): fields \(bucket.fields.joined(separator: ", "))")
            if !bucket.primaryFields.isEmpty {
                lines.append("Bucket \(bucketName) primary fields: \(bucket.primaryFields.joined(separator: ", "))")
            }
            if !bucket.secondaryFields.isEmpty {
                lines.append("Bucket \(bucketName) secondary fields: \(bucket.secondaryFields.joined(separator: ", "))")
            }
            if !bucket.creditsFields.isEmpty {
                lines.append("Bucket \(bucketName) credits fields: \(bucket.creditsFields.joined(separator: ", "))")
            }
        }

        return lines
    }

    private static func displayName(for bucket: CodexUsageBucketFieldInventory) -> String {
        CodexUsageSensitiveNameRedactor.redactedBucketIdentifier(
            key: bucket.key,
            limitId: bucket.limitId
        )
    }
}
