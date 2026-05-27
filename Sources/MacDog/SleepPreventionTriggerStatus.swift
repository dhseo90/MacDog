import AppKit
import Foundation

struct SleepPreventionTriggerStatus: Equatable {
    static let disabled = SleepPreventionTriggerStatus(
        powerAdapterTriggerEnabled: false,
        codexAppTriggerEnabled: false,
        chargingBelowThresholdTriggerEnabled: false,
        cpuThresholdTriggerEnabled: false,
        networkActivityTriggerEnabled: false,
        externalVolumeTriggerEnabled: false,
        powerAdapterConnected: false,
        codexAppRunning: false,
        chargingBelowThreshold: false,
        cpuAboveThreshold: false,
        networkActivityAboveThreshold: false,
        externalVolumeConnected: false,
        batteryPercent: nil,
        batteryThresholdPercent: RunnerPreferences.sleepPreventionBatteryThresholdPercent,
        cpuLoadPercent: nil,
        cpuThresholdPercent: RunnerPreferences.sleepPreventionCPUThresholdPercent,
        networkActivityBytesPerSecond: nil,
        networkActivityThresholdBytesPerSecond: RunnerPreferences.sleepPreventionNetworkActivityThresholdBytesPerSecond,
        externalVolumeCount: 0
    )

    let powerAdapterTriggerEnabled: Bool
    let codexAppTriggerEnabled: Bool
    let chargingBelowThresholdTriggerEnabled: Bool
    let cpuThresholdTriggerEnabled: Bool
    let networkActivityTriggerEnabled: Bool
    let externalVolumeTriggerEnabled: Bool
    let powerAdapterConnected: Bool
    let codexAppRunning: Bool
    let chargingBelowThreshold: Bool
    let cpuAboveThreshold: Bool
    let networkActivityAboveThreshold: Bool
    let externalVolumeConnected: Bool
    let batteryPercent: Int?
    let batteryThresholdPercent: Int
    let cpuLoadPercent: Double?
    let cpuThresholdPercent: Int
    let networkActivityBytesPerSecond: Double?
    let networkActivityThresholdBytesPerSecond: Double
    let externalVolumeCount: Int

    static func capture(preferences: RunnerPreferences, systemMetrics: SystemMetricsSnapshot = .capture()) -> SleepPreventionTriggerStatus {
        evaluate(
            preferences: preferences,
            systemMetrics: systemMetrics,
            codexAppRunning: Self.isCodexAppRunning(),
            externalVolumeCount: Self.externalVolumeCount()
        )
    }

    static func evaluate(
        preferences: RunnerPreferences,
        systemMetrics: SystemMetricsSnapshot,
        codexAppRunning: Bool,
        externalVolumeCount: Int
    ) -> SleepPreventionTriggerStatus {
        let batteryThreshold = RunnerPreferences.sleepPreventionBatteryThresholdPercent
        let cpuThreshold = RunnerPreferences.sleepPreventionCPUThresholdPercent
        let networkThreshold = RunnerPreferences.sleepPreventionNetworkActivityThresholdBytesPerSecond
        let battery = systemMetrics.battery
        let networkActivityBytesPerSecond = Self.networkActivityBytesPerSecond(systemMetrics)

        return SleepPreventionTriggerStatus(
            powerAdapterTriggerEnabled: preferences.sleepPreventionPowerAdapterTriggerEnabled,
            codexAppTriggerEnabled: preferences.sleepPreventionCodexAppTriggerEnabled,
            chargingBelowThresholdTriggerEnabled: preferences.sleepPreventionChargingBelowThresholdTriggerEnabled,
            cpuThresholdTriggerEnabled: preferences.sleepPreventionCPUThresholdTriggerEnabled,
            networkActivityTriggerEnabled: preferences.sleepPreventionNetworkActivityTriggerEnabled,
            externalVolumeTriggerEnabled: preferences.sleepPreventionExternalVolumeTriggerEnabled,
            powerAdapterConnected: battery.isConnectedToPower == true,
            codexAppRunning: codexAppRunning,
            chargingBelowThreshold: battery.isConnectedToPower == true && (battery.percent ?? 101) < batteryThreshold,
            cpuAboveThreshold: (systemMetrics.cpuLoadPercent ?? 0) >= Double(cpuThreshold),
            networkActivityAboveThreshold: (networkActivityBytesPerSecond ?? 0) >= networkThreshold,
            externalVolumeConnected: externalVolumeCount > 0,
            batteryPercent: battery.percent,
            batteryThresholdPercent: batteryThreshold,
            cpuLoadPercent: systemMetrics.cpuLoadPercent,
            cpuThresholdPercent: cpuThreshold,
            networkActivityBytesPerSecond: networkActivityBytesPerSecond,
            networkActivityThresholdBytesPerSecond: networkThreshold,
            externalVolumeCount: externalVolumeCount
        )
    }

    var isMatched: Bool {
        (powerAdapterTriggerEnabled && powerAdapterConnected) ||
        (codexAppTriggerEnabled && codexAppRunning) ||
        (chargingBelowThresholdTriggerEnabled && chargingBelowThreshold) ||
        (cpuThresholdTriggerEnabled && cpuAboveThreshold) ||
        (networkActivityTriggerEnabled && networkActivityAboveThreshold) ||
        (externalVolumeTriggerEnabled && externalVolumeConnected)
    }

    var summary: String {
        guard hasEnabledTrigger else {
            return "꺼짐"
        }

        let matches = matchedLabels
        if matches.isEmpty {
            return "대기 중"
        }
        return "활성 · \(matches.joined(separator: ", "))"
    }

    private var hasEnabledTrigger: Bool {
        powerAdapterTriggerEnabled ||
        codexAppTriggerEnabled ||
        chargingBelowThresholdTriggerEnabled ||
        cpuThresholdTriggerEnabled ||
        networkActivityTriggerEnabled ||
        externalVolumeTriggerEnabled
    }

    private var matchedLabels: [String] {
        var labels: [String] = []
        if powerAdapterTriggerEnabled && powerAdapterConnected {
            labels.append("전원")
        }
        if codexAppTriggerEnabled && codexAppRunning {
            labels.append("Codex")
        }
        if chargingBelowThresholdTriggerEnabled && chargingBelowThreshold {
            labels.append("충전 \(batteryThresholdPercent)% 미만")
        }
        if cpuThresholdTriggerEnabled && cpuAboveThreshold {
            labels.append("CPU")
        }
        if networkActivityTriggerEnabled && networkActivityAboveThreshold {
            labels.append("네트워크")
        }
        if externalVolumeTriggerEnabled && externalVolumeConnected {
            labels.append("볼륨")
        }
        return labels
    }

    private static func networkActivityBytesPerSecond(_ systemMetrics: SystemMetricsSnapshot) -> Double? {
        switch (systemMetrics.networkReceivedRateBytesPerSecond, systemMetrics.networkSentRateBytesPerSecond) {
        case let (.some(received), .some(sent)):
            return received + sent
        case let (.some(received), .none):
            return received
        case let (.none, .some(sent)):
            return sent
        case (.none, .none):
            return nil
        }
    }

    private static func isCodexAppRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains { application in
            let bundleIdentifier = application.bundleIdentifier?.lowercased() ?? ""
            let name = application.localizedName?.lowercased() ?? ""
            return bundleIdentifier.contains("codex") || name.contains("codex")
        }
    }

    private static func externalVolumeCount() -> Int {
        let keys: [URLResourceKey] = [
            .volumeIsInternalKey,
            .volumeIsLocalKey,
            .volumeIsRemovableKey,
            .volumeIsEjectableKey
        ]
        let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) ?? []

        return urls.filter { url in
            guard url.path != "/" else { return false }
            let values = try? url.resourceValues(forKeys: Set(keys))
            return values?.volumeIsInternal != true
        }.count
    }
}
