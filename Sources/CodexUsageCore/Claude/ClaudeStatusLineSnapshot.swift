import Foundation

public enum ClaudeUsageWindowKind: String, Codable, CaseIterable, Equatable, Sendable {
    case fiveHour = "five_hour"
    case sevenDay = "seven_day"

    public var windowDurationMins: Int {
        switch self {
        case .fiveHour:
            300
        case .sevenDay:
            10_080
        }
    }
}

public struct ClaudeUsageWindowSnapshot: Codable, Equatable, Sendable {
    public let usedPercent: Double?
    public let resetsAt: Int?

    public init(usedPercent: Double?, resetsAt: Int?) throws {
        if let usedPercent,
           (!usedPercent.isFinite || usedPercent < 0 || usedPercent > 100) {
            throw ClaudeStatusLineSanitizationError.invalidUsagePercent
        }
        if let resetsAt, resetsAt <= 0 {
            throw ClaudeStatusLineSanitizationError.invalidResetTimestamp
        }
        self.usedPercent = usedPercent
        self.resetsAt = resetsAt
    }

    public var isEmpty: Bool {
        usedPercent == nil && resetsAt == nil
    }
}

public struct ClaudeStatusLineSnapshot: Codable, Equatable, Sendable {
    public static let providerID = "claude"

    public let provider: String
    public let observedAt: Int
    public let fiveHour: ClaudeUsageWindowSnapshot?
    public let sevenDay: ClaudeUsageWindowSnapshot?

    public init(
        observedAt: Int,
        fiveHour: ClaudeUsageWindowSnapshot?,
        sevenDay: ClaudeUsageWindowSnapshot?
    ) {
        self.provider = Self.providerID
        self.observedAt = observedAt
        self.fiveHour = fiveHour?.isEmpty == false ? fiveHour : nil
        self.sevenDay = sevenDay?.isEmpty == false ? sevenDay : nil
    }

    public var hasUsageData: Bool {
        fiveHour?.usedPercent != nil || sevenDay?.usedPercent != nil
    }

    public var maxUsedPercent: Double {
        [fiveHour?.usedPercent, sevenDay?.usedPercent]
            .compactMap(\.self)
            .max() ?? 0
    }

    public func window(_ kind: ClaudeUsageWindowKind) -> ClaudeUsageWindowSnapshot? {
        switch kind {
        case .fiveHour:
            fiveHour
        case .sevenDay:
            sevenDay
        }
    }
}

public enum ClaudeStatusLineSanitizationError: LocalizedError, Equatable, Sendable {
    case invalidJSON
    case invalidUsagePercent
    case invalidResetTimestamp

    public var errorDescription: String? {
        switch self {
        case .invalidJSON:
            "Claude status line JSON을 해석할 수 없습니다."
        case .invalidUsagePercent:
            "Claude 사용률은 0~100 범위여야 합니다."
        case .invalidResetTimestamp:
            "Claude reset 시각이 올바르지 않습니다."
        }
    }

    public var cacheCode: String {
        switch self {
        case .invalidJSON:
            "status_line_decode_failed"
        case .invalidUsagePercent:
            "invalid_usage_percent"
        case .invalidResetTimestamp:
            "invalid_reset_timestamp"
        }
    }
}

public struct ClaudeStatusLineSanitizer: Sendable {
    public init() {}

    public func snapshot(from data: Data, observedAt: Int) throws -> ClaudeStatusLineSnapshot {
        let payload: Payload
        do {
            payload = try JSONDecoder().decode(Payload.self, from: data)
        } catch let error as ClaudeStatusLineSanitizationError {
            throw error
        } catch {
            throw ClaudeStatusLineSanitizationError.invalidJSON
        }

        return ClaudeStatusLineSnapshot(
            observedAt: observedAt,
            fiveHour: try sanitizedWindow(payload.rateLimits?.fiveHour),
            sevenDay: try sanitizedWindow(payload.rateLimits?.sevenDay)
        )
    }

    private func sanitizedWindow(_ window: Payload.Window?) throws -> ClaudeUsageWindowSnapshot? {
        guard let window else { return nil }
        let sanitized = try ClaudeUsageWindowSnapshot(
            usedPercent: window.usedPercentage,
            resetsAt: window.resetsAt
        )
        return sanitized.isEmpty ? nil : sanitized
    }

    private struct Payload: Decodable {
        let rateLimits: RateLimits?

        enum CodingKeys: String, CodingKey {
            case rateLimits = "rate_limits"
        }

        struct RateLimits: Decodable {
            let fiveHour: Window?
            let sevenDay: Window?

            enum CodingKeys: String, CodingKey {
                case fiveHour = "five_hour"
                case sevenDay = "seven_day"
            }
        }

        struct Window: Decodable {
            let usedPercentage: Double?
            let resetsAt: Int?

            enum CodingKeys: String, CodingKey {
                case usedPercentage = "used_percentage"
                case resetsAt = "resets_at"
            }
        }
    }
}
