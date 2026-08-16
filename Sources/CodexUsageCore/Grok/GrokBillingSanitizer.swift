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
        if let cycle = stringValue(object["billingCycle"])?.lowercased(),
           cycle == "monthly" {
            throw GrokBillingSanitizationError.weeklyWindowMissing
        }
        guard let usedPercent = doubleValue(object["creditUsagePercent"]) else {
            throw GrokBillingSanitizationError.weeklyWindowMissing
        }
        guard (0...100).contains(usedPercent) else {
            throw GrokBillingSanitizationError.invalidUsagePercent
        }
        let resetsAt = firstUnixTimestamp(in: object, keys: ["resetsAt", "resetAt", "nextReset", "next_reset"])
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
        if let result = object["result"] as? [String: Any] {
            return result
        }
        return object
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
