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

    public init(rateLimits: RateLimitSnapshot, rateLimitsByLimitId: [String: RateLimitSnapshot]?) {
        self.rateLimits = rateLimits
        self.rateLimitsByLimitId = rateLimitsByLimitId
    }

    public var codexBucket: RateLimitSnapshot {
        rateLimitsByLimitId?["codex"] ?? rateLimits
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

