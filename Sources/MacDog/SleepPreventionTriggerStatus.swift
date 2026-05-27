import AppKit
import Foundation

struct SleepPreventionTriggerStatus: Equatable {
    static let disabled = SleepPreventionTriggerStatus(
        powerAdapterTriggerEnabled: false,
        codexAppTriggerEnabled: false,
        powerAdapterConnected: false,
        codexAppRunning: false
    )

    let powerAdapterTriggerEnabled: Bool
    let codexAppTriggerEnabled: Bool
    let powerAdapterConnected: Bool
    let codexAppRunning: Bool

    static func capture(preferences: RunnerPreferences) -> SleepPreventionTriggerStatus {
        SleepPreventionTriggerStatus(
            powerAdapterTriggerEnabled: preferences.sleepPreventionPowerAdapterTriggerEnabled,
            codexAppTriggerEnabled: preferences.sleepPreventionCodexAppTriggerEnabled,
            powerAdapterConnected: BatteryStatusSnapshot.capture().isConnectedToPower == true,
            codexAppRunning: Self.isCodexAppRunning()
        )
    }

    var isMatched: Bool {
        (powerAdapterTriggerEnabled && powerAdapterConnected) ||
        (codexAppTriggerEnabled && codexAppRunning)
    }

    var summary: String {
        guard powerAdapterTriggerEnabled || codexAppTriggerEnabled else {
            return "꺼짐"
        }

        let matches = matchedLabels
        if matches.isEmpty {
            return "대기 중"
        }
        return "활성 · \(matches.joined(separator: ", "))"
    }

    private var matchedLabels: [String] {
        var labels: [String] = []
        if powerAdapterTriggerEnabled && powerAdapterConnected {
            labels.append("전원")
        }
        if codexAppTriggerEnabled && codexAppRunning {
            labels.append("Codex")
        }
        return labels
    }

    private static func isCodexAppRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains { application in
            let bundleIdentifier = application.bundleIdentifier?.lowercased() ?? ""
            let name = application.localizedName?.lowercased() ?? ""
            return bundleIdentifier.contains("codex") || name.contains("codex")
        }
    }
}
