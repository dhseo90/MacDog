import Foundation

public struct CodexUsageReport: Codable, Equatable, Sendable {
    public let generatedAt: Int
    public let source: String
    public let planType: String?
    public let credits: CreditsSnapshot?
    public let rateLimitReachedType: String?
    public let limits: [String: UsageLimitReport]

    public init(
        generatedAt: Int,
        source: String,
        planType: String?,
        credits: CreditsSnapshot?,
        rateLimitReachedType: String?,
        limits: [String: UsageLimitReport]
    ) {
        self.generatedAt = generatedAt
        self.source = source
        self.planType = planType
        self.credits = credits
        self.rateLimitReachedType = rateLimitReachedType
        self.limits = limits
    }

    public var codexLimit: UsageLimitReport? {
        if let preferred = limits["codex"] {
            return preferred.hasRequiredCodexUsageWindows ? preferred : nil
        }

        return limits.values.first { $0.hasRequiredCodexUsageWindows }
    }

    public func validateRequiredCodexUsageWindows() throws {
        guard let candidate = limits["codex"] ?? limits.values.first else {
            throw CodexUsageReportValidationError.missingRequiredCodexWindows([
                .fiveHour,
                .weekly
            ])
        }

        let missing = candidate.missingRequiredCodexUsageWindows
        if !missing.isEmpty {
            throw CodexUsageReportValidationError.missingRequiredCodexWindows(missing)
        }
    }
}

public enum CodexUsageReportValidationError: LocalizedError, Equatable, Sendable {
    case missingRequiredCodexWindows([UsageWindowKind])

    public var errorDescription: String? {
        switch self {
        case .missingRequiredCodexWindows(let missing):
            let labels = missing.map(Self.label).joined(separator: ", ")
            return "missing required codex usage windows: \(labels)"
        }
    }

    private static func label(for kind: UsageWindowKind) -> String {
        switch kind {
        case .fiveHour:
            return "5-hour"
        case .weekly:
            return "weekly"
        case .other:
            return "other"
        }
    }
}

public struct CodexUsageDiagnosticReport: Equatable, Sendable {
    public let report: CodexUsageReport
    public let fieldInventory: CodexUsageFieldInventory

    public init(report: CodexUsageReport, fieldInventory: CodexUsageFieldInventory) {
        self.report = report
        self.fieldInventory = fieldInventory
    }
}

public struct UsageLimitReport: Codable, Equatable, Sendable {
    public let limitId: String?
    public let limitName: String?
    public let primary: UsageWindowReport?
    public let secondary: UsageWindowReport?
    public let credits: CreditsSnapshot?
    public let planType: String?
    public let rateLimitReachedType: String?

    public init(
        limitId: String?,
        limitName: String?,
        primary: UsageWindowReport?,
        secondary: UsageWindowReport?,
        credits: CreditsSnapshot?,
        planType: String?,
        rateLimitReachedType: String?
    ) {
        self.limitId = limitId
        self.limitName = limitName
        self.primary = primary
        self.secondary = secondary
        self.credits = credits
        self.planType = planType
        self.rateLimitReachedType = rateLimitReachedType
    }

    public var fiveHour: UsageWindowReport? {
        [primary, secondary].compactMap(\.self).first { $0.kind == .fiveHour }
    }

    public var weekly: UsageWindowReport? {
        [primary, secondary].compactMap(\.self).first { $0.kind == .weekly }
    }

    public var maxUsedPercent: Double {
        [fiveHour?.usedPercent, weekly?.usedPercent]
            .compactMap(\.self)
            .max() ?? 0
    }

    public var missingRequiredCodexUsageWindows: [UsageWindowKind] {
        var missing: [UsageWindowKind] = []
        if fiveHour == nil {
            missing.append(.fiveHour)
        }
        if weekly == nil {
            missing.append(.weekly)
        }
        return missing
    }

    public var hasRequiredCodexUsageWindows: Bool {
        missingRequiredCodexUsageWindows.isEmpty
    }
}

public struct UsageWindowReport: Codable, Equatable, Sendable {
    public let kind: UsageWindowKind
    public let usedPercent: Double
    public let remainingPercent: Double
    public let windowDurationMins: Int?
    public let resetsAt: Int?

    public init(
        kind: UsageWindowKind,
        usedPercent: Double,
        remainingPercent: Double,
        windowDurationMins: Int?,
        resetsAt: Int?
    ) {
        self.kind = kind
        self.usedPercent = usedPercent
        self.remainingPercent = remainingPercent
        self.windowDurationMins = windowDurationMins
        self.resetsAt = resetsAt
    }
}

public struct CodexUsageReportBuilder: Sendable {
    private let dateProvider: @Sendable () -> Date

    public init(dateProvider: @escaping @Sendable () -> Date = Date.init) {
        self.dateProvider = dateProvider
    }

    public func build(from response: RateLimitsResponse) throws -> CodexUsageReport {
        let buckets = response.rateLimitsByLimitId ?? [
            response.rateLimits.limitId ?? "codex": response.rateLimits
        ]
        let limits = buckets.mapValues(Self.makeLimitReport)
        let codex = limits["codex"] ?? limits.values.first

        let report = CodexUsageReport(
            generatedAt: Int(dateProvider().timeIntervalSince1970),
            source: "codex-app-server",
            planType: codex?.planType,
            credits: codex?.credits,
            rateLimitReachedType: codex?.rateLimitReachedType,
            limits: limits
        )
        try report.validateRequiredCodexUsageWindows()
        return report
    }

    public func buildDiagnosticReport(
        from response: RateLimitsResponse,
        fieldInventory: CodexUsageFieldInventory
    ) throws -> CodexUsageDiagnosticReport {
        let report = try build(from: response)
        return CodexUsageDiagnosticReport(
            report: report,
            fieldInventory: fieldInventory
        )
    }

    private static func makeLimitReport(from snapshot: RateLimitSnapshot) -> UsageLimitReport {
        UsageLimitReport(
            limitId: snapshot.limitId,
            limitName: snapshot.limitName,
            primary: snapshot.primary.map(makeWindowReport),
            secondary: snapshot.secondary.map(makeWindowReport),
            credits: snapshot.credits,
            planType: snapshot.planType,
            rateLimitReachedType: snapshot.rateLimitReachedType
        )
    }

    private static func makeWindowReport(from window: RateLimitWindow) -> UsageWindowReport {
        UsageWindowReport(
            kind: window.identifiedKind,
            usedPercent: window.usedPercent,
            remainingPercent: window.remainingPercent,
            windowDurationMins: window.windowDurationMins,
            resetsAt: window.resetsAt
        )
    }
}
