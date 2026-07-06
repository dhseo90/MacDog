import Foundation

public struct RateLimitWindow: Codable, Equatable, Sendable {
    public let usedPercent: Double
    public let windowDurationMins: Int?
    public let resetsAt: Int?

    public init(usedPercent: Double, windowDurationMins: Int?, resetsAt: Int?) {
        self.usedPercent = usedPercent
        self.windowDurationMins = windowDurationMins
        self.resetsAt = resetsAt
    }

    public var remainingPercent: Double {
        max(0, 100 - usedPercent)
    }
}

public struct CreditsSnapshot: Codable, Equatable, Sendable {
    public let hasCredits: Bool
    public let unlimited: Bool
    public let balance: String?

    public init(hasCredits: Bool, unlimited: Bool, balance: String?) {
        self.hasCredits = hasCredits
        self.unlimited = unlimited
        self.balance = balance
    }
}

public struct RateLimitResetCreditsSummary: Codable, Equatable, Sendable {
    public let availableCount: Int
    public let credits: [RateLimitResetCredit]

    public init(availableCount: Int, credits: [RateLimitResetCredit] = []) {
        self.availableCount = availableCount
        self.credits = credits
    }

    private enum CodingKeys: String, CodingKey {
        case availableCount
        case available_count
        case credits
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let availableCount = try container.decodeIfPresent(Int.self, forKey: .availableCount) {
            self.availableCount = availableCount
        } else {
            self.availableCount = try container.decode(Int.self, forKey: .available_count)
        }
        self.credits = try container.decodeIfPresent([RateLimitResetCredit].self, forKey: .credits) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(availableCount, forKey: .availableCount)
        if !credits.isEmpty {
            try container.encode(credits, forKey: .credits)
        }
    }
}

public struct RateLimitResetCredit: Codable, Equatable, Sendable, Identifiable {
    public let id: String?
    public let status: String?
    public let resetType: String?
    public let expiresAt: String?
    public let title: String?
    public let description: String?

    public init(
        id: String?,
        status: String?,
        resetType: String?,
        expiresAt: String?,
        title: String? = nil,
        description: String? = nil
    ) {
        self.id = id
        self.status = status
        self.resetType = resetType
        self.expiresAt = expiresAt
        self.title = title
        self.description = description
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case status
        case resetType
        case reset_type
        case expiresAt
        case expires_at
        case title
        case description
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.status = try container.decodeIfPresent(String.self, forKey: .status)
        self.resetType = try container.decodeIfPresent(String.self, forKey: .resetType) ??
            container.decodeIfPresent(String.self, forKey: .reset_type)
        self.expiresAt = try container.decodeIfPresent(String.self, forKey: .expiresAt) ??
            container.decodeIfPresent(String.self, forKey: .expires_at)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(resetType, forKey: .resetType)
        try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
    }
}

public struct RateLimitSnapshot: Codable, Equatable, Sendable {
    public let limitId: String?
    public let limitName: String?
    public let primary: RateLimitWindow?
    public let secondary: RateLimitWindow?
    public let credits: CreditsSnapshot?
    public let planType: String?
    public let rateLimitReachedType: String?

    public init(
        limitId: String?,
        limitName: String?,
        primary: RateLimitWindow?,
        secondary: RateLimitWindow?,
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
}

public struct RateLimitsResponse: Codable, Equatable, Sendable {
    public let rateLimits: RateLimitSnapshot
    public let rateLimitsByLimitId: [String: RateLimitSnapshot]?
    public let rateLimitResetCredits: RateLimitResetCreditsSummary?

    public init(
        rateLimits: RateLimitSnapshot,
        rateLimitsByLimitId: [String: RateLimitSnapshot]?,
        rateLimitResetCredits: RateLimitResetCreditsSummary? = nil
    ) {
        self.rateLimits = rateLimits
        self.rateLimitsByLimitId = rateLimitsByLimitId
        self.rateLimitResetCredits = rateLimitResetCredits
    }

    public var codexBucket: RateLimitSnapshot {
        rateLimitsByLimitId?["codex"] ?? rateLimits
    }

    private enum CodingKeys: String, CodingKey {
        case rateLimits
        case rateLimitsByLimitId
        case rateLimitResetCredits
        case rate_limit_reset_credits
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.rateLimits = try container.decode(RateLimitSnapshot.self, forKey: .rateLimits)
        self.rateLimitsByLimitId = try container.decodeIfPresent(
            [String: RateLimitSnapshot].self,
            forKey: .rateLimitsByLimitId
        )
        self.rateLimitResetCredits = try container.decodeIfPresent(
            RateLimitResetCreditsSummary.self,
            forKey: .rateLimitResetCredits
        ) ?? container.decodeIfPresent(
            RateLimitResetCreditsSummary.self,
            forKey: .rate_limit_reset_credits
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rateLimits, forKey: .rateLimits)
        try container.encodeIfPresent(rateLimitsByLimitId, forKey: .rateLimitsByLimitId)
        try container.encodeIfPresent(rateLimitResetCredits, forKey: .rateLimitResetCredits)
    }
}

public enum UsageWindowKind: String, Codable, Equatable, Sendable {
    case fiveHour
    case weekly
    case other
}

public struct IdentifiedUsageWindow: Codable, Equatable, Sendable {
    public let kind: UsageWindowKind
    public let window: RateLimitWindow

    public init(kind: UsageWindowKind, window: RateLimitWindow) {
        self.kind = kind
        self.window = window
    }
}

public extension RateLimitWindow {
    var identifiedKind: UsageWindowKind {
        switch windowDurationMins {
        case 300:
            .fiveHour
        case 10_080:
            .weekly
        default:
            .other
        }
    }
}

public extension RateLimitSnapshot {
    var fiveHourWindow: RateLimitWindow? {
        [primary, secondary].compactMap(\.self).first { $0.identifiedKind == .fiveHour }
    }

    var weeklyWindow: RateLimitWindow? {
        [primary, secondary].compactMap(\.self).first { $0.identifiedKind == .weekly }
    }

    var allWindows: [IdentifiedUsageWindow] {
        [primary, secondary]
            .compactMap(\.self)
            .map { IdentifiedUsageWindow(kind: $0.identifiedKind, window: $0) }
    }
}
