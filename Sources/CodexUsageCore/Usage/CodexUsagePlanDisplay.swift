import Foundation

public enum CodexUsagePlanDisplay {
    public static func displayLabel(rawPlanType: String?) -> String {
        rawPlanType ?? "unknown"
    }

    public static func pricingTierLabel(rawPlanType _: String?) -> String? {
        nil
    }
}
