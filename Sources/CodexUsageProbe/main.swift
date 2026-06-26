import CodexUsageCore
import Foundation

do {
    let client = try CodexAppServerClient()
    let response = try client.readRateLimits()
    let bucket = response.codexBucket

    print("Codex app-server usage probe")
    print("Plan: \(CodexUsagePlanDisplay.displayLabel(rawPlanType: bucket.planType))")

    if let fiveHour = bucket.fiveHourWindow {
        print("5h used: \(format(fiveHour.usedPercent))%")
    } else {
        print("5h used: unavailable")
    }

    if let weekly = bucket.weeklyWindow {
        print("Weekly used: \(format(weekly.usedPercent))%")
    } else {
        print("Weekly used: unavailable")
    }

    if let credits = bucket.credits {
        print("Credits: \(credits.balance ?? "unknown")")
    }
} catch {
    fputs("codex-usage-probe: \(error.localizedDescription)\n", stderr)
    exit(1)
}

private func format(_ value: Double) -> String {
    if value.rounded() == value {
        return String(Int(value))
    }
    return String(format: "%.1f", value)
}
