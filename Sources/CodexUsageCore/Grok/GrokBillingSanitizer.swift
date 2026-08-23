import Foundation

public enum GrokBillingSanitizationError: Error, Equatable, Sendable {
    case decodeFailed
    case weeklyWindowMissing
    case invalidUsagePercent
    case payloadTooLarge

    public var cacheCode: String {
        switch self {
        case .decodeFailed:
            "billing-decode-failed"
        case .weeklyWindowMissing:
            "weekly-window-missing"
        case .invalidUsagePercent:
            "weekly-window-missing"
        case .payloadTooLarge:
            "billing-too-large"
        }
    }
}

public enum GrokBillingSanitizer: Sendable {
    public static let maximumBillingBytes = 1_048_576

    public static func weeklyWindow(from data: Data) throws -> GrokUsageWeeklyWindow {
        guard data.count <= maximumBillingBytes else {
            throw GrokBillingSanitizationError.payloadTooLarge
        }
        let object = try billingObject(from: data)
        if isMonthlyCycle(object) {
            throw GrokBillingSanitizationError.weeklyWindowMissing
        }
        guard let usedPercent = doubleValue(object["creditUsagePercent"]) else {
            throw GrokBillingSanitizationError.weeklyWindowMissing
        }
        guard (0...100).contains(usedPercent) else {
            throw GrokBillingSanitizationError.invalidUsagePercent
        }
        let resetsAt = firstResetTimestamp(in: object)
        guard let weekly = GrokUsageWeeklyWindow(usedPercent: usedPercent, resetsAt: resetsAt) else {
            throw GrokBillingSanitizationError.invalidUsagePercent
        }
        return weekly
    }

    private static func billingObject(from data: Data) throws -> [String: Any] {
        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw GrokBillingSanitizationError.decodeFailed
        }
        guard let object = json as? [String: Any] else {
            throw GrokBillingSanitizationError.decodeFailed
        }
        let candidates = [
            object["result"] as? [String: Any],
            object["config"] as? [String: Any],
            object
        ].compactMap { $0 }
        if let match = candidates.first(where: { $0["creditUsagePercent"] != nil }) {
            return match
        }
        return candidates.first ?? object
    }

    private static func isMonthlyCycle(_ object: [String: Any]) -> Bool {
        if let cycle = stringValue(object["billingCycle"])?.lowercased(),
           cycle.contains("month") {
            return true
        }
        if let period = object["currentPeriod"] as? [String: Any],
           let type = stringValue(period["type"])?.lowercased(),
           type.contains("month") {
            return true
        }
        return false
    }

    private static func firstResetTimestamp(in object: [String: Any]) -> Int? {
        let unixKeys = ["resetsAt", "resetAt", "nextReset", "next_reset"]
        if let timestamp = firstUnixTimestamp(in: object, keys: unixKeys) {
            return timestamp
        }
        let isoKeys = ["billingPeriodEnd", "resetsAt", "resetAt", "nextReset", "next_reset"]
        for key in isoKeys {
            if let timestamp = unixFromISO8601(object[key]) {
                return timestamp
            }
        }
        if let period = object["currentPeriod"] as? [String: Any],
           let timestamp = unixFromISO8601(period["end"]) {
            return timestamp
        }
        return nil
    }

    private static func unixFromISO8601(_ value: Any?) -> Int? {
        guard let raw = value as? String, !raw.isEmpty else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: raw) {
            return Int(date.timeIntervalSince1970)
        }
        let basic = ISO8601DateFormatter()
        basic.formatOptions = [.withInternetDateTime]
        if let date = basic.date(from: raw) {
            return Int(date.timeIntervalSince1970)
        }
        if let trimmed = trimmedFractionalISO8601(raw) {
            if let date = fractional.date(from: trimmed) ?? basic.date(from: trimmed) {
                return Int(date.timeIntervalSince1970)
            }
        }
        return nil
    }

    private static func trimmedFractionalISO8601(_ raw: String) -> String? {
        guard let dot = raw.firstIndex(of: "."),
              let timezone = raw.lastIndex(where: { $0 == "+" || $0 == "-" || $0 == "Z" }),
              dot < timezone else {
            return nil
        }
        let fraction = raw[raw.index(after: dot)..<timezone]
        let digits = fraction.prefix { $0.isNumber }
        guard digits.count > 3 else { return nil }
        return String(raw[..<raw.index(after: dot)]) + String(digits.prefix(3)) + String(raw[timezone...])
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            return number.doubleValue
        case let number as Double:
            return number
        case let number as Int:
            return Double(number)
        default:
            return nil
        }
    }

    private static func stringValue(_ value: Any?) -> String? {
        value as? String
    }

    private static func firstUnixTimestamp(in object: [String: Any], keys: [String]) -> Int? {
        for key in keys {
            if let value = intValue(object[key]), value > 1_000_000_000 {
                return value
            }
        }
        return nil
    }

    private static func intValue(_ value: Any?) -> Int? {
        switch value {
        case let number as Int:
            return number
        case let number as NSNumber:
            return number.intValue
        default:
            return nil
        }
    }
}
