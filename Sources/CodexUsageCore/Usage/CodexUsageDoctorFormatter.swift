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

    public func usageHealthLines(from report: CodexUsageHealthReport) -> [String] {
        let summaryLines = [
            [
                "Cache:",
                report.cacheState.rawValue,
                "age=\(report.cacheAgeSeconds.map { "\($0)s" } ?? "unavailable")",
                "staleAfter=\(report.cacheStaleAfterSeconds.map { "\($0)s" } ?? "unavailable")",
                "report=\(report.cacheHasReport ? "yes" : "no")",
                "path=\(report.cacheFileURL.path)"
            ].joined(separator: " "),
            [
                "Weekly history:",
                report.weeklyHistoryState.rawValue,
                "samples=\(report.weeklySampleCount)",
                "append=\(report.weeklyAppendState.rawValue)",
                "latestReset=\(report.latestWeeklySampleResetsAt.map(String.init) ?? "unavailable")",
                "path=\(report.weeklyHistoryFileURL.path)"
            ].joined(separator: " "),
            [
                "Reset window history:",
                report.resetWindowHistoryState.rawValue,
                "records=\(report.resetWindowRecordCount)",
                "append=\(report.resetWindowAppendState.rawValue)",
                "retention=\(report.resetWindowRetentionState.rawValue)/\(report.resetWindowRetentionLimit)",
                "latestReset=\(report.latestResetWindowResetsAt.map(String.init) ?? "unavailable")",
                "path=\(report.resetWindowHistoryFileURL.path)"
            ].joined(separator: " "),
            [
                "Pace:",
                report.paceState.rawValue,
                "samples=\(report.paceSampleCount)"
            ].joined(separator: " ")
        ]
        return summaryLines + [nextStepLine(from: report)]
    }

    private static func displayName(for bucket: CodexUsageBucketFieldInventory) -> String {
        CodexUsageSensitiveNameRedactor.redactedBucketIdentifier(
            key: bucket.key,
            limitId: bucket.limitId
        )
    }

    private func nextStepLine(from report: CodexUsageHealthReport) -> String {
        switch report.cacheState {
        case .missing:
            return "Next: run `codex-usage status --write-cache` to create the app-owned cache."
        case .stale:
            return "Next: run `codex-usage status --write-cache` or check the usage cache LaunchAgent cadence."
        case .error:
            return "Next: retry `codex-usage status --write-cache`; if it still fails, restart Codex before relying on live usage."
        case .waiting:
            return "Next: wait for the first successful `codex-usage status --write-cache` cache snapshot."
        case .ok:
            if report.weeklyHistoryState != .ok || report.resetWindowHistoryState != .ok {
                return "Next: keep `codex-usage status --write-cache` running until weekly and reset-window history have samples."
            }
            return "Next: cache and history health are ready for Codex tab usage."
        }
    }
}
