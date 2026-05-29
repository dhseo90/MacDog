import AppKit
import Foundation

struct SleepPreventionTriggerStatus: Equatable {
    static let disabled = SleepPreventionTriggerStatus(
        powerAdapterTriggerEnabled: false,
        codexAppTriggerEnabled: false,
        chargingBelowThresholdTriggerEnabled: false,
        cpuThresholdTriggerEnabled: false,
        memoryThresholdTriggerEnabled: false,
        networkActivityTriggerEnabled: false,
        externalVolumeTriggerEnabled: false,
        powerAdapterConnected: false,
        codexAppRunning: false,
        appMatchText: RunnerPreferences.defaultSleepPreventionAppMatchText,
        chargingBelowThreshold: false,
        cpuAboveThreshold: false,
        memoryAboveThreshold: false,
        networkActivityAboveThreshold: false,
        externalVolumeConnected: false,
        batteryPercent: nil,
        batteryThresholdPercent: RunnerPreferences.defaultSleepPreventionBatteryThresholdPercent,
        cpuLoadPercent: nil,
        cpuThresholdPercent: RunnerPreferences.defaultSleepPreventionCPUThresholdPercent,
        memoryUsedPercent: nil,
        memoryThresholdPercent: RunnerPreferences.defaultSleepPreventionMemoryThresholdPercent,
        networkActivityBytesPerSecond: nil,
        networkActivityThresholdBytesPerSecond: Double(RunnerPreferences.defaultSleepPreventionNetworkThresholdKBPerSecond) * 1024,
        externalVolumeCount: 0
    )

    let powerAdapterTriggerEnabled: Bool
    let codexAppTriggerEnabled: Bool
    let chargingBelowThresholdTriggerEnabled: Bool
    let cpuThresholdTriggerEnabled: Bool
    let memoryThresholdTriggerEnabled: Bool
    let networkActivityTriggerEnabled: Bool
    let externalVolumeTriggerEnabled: Bool
    let powerAdapterConnected: Bool
    let codexAppRunning: Bool
    let appMatchText: String
    let chargingBelowThreshold: Bool
    let cpuAboveThreshold: Bool
    let memoryAboveThreshold: Bool
    let networkActivityAboveThreshold: Bool
    let externalVolumeConnected: Bool
    let batteryPercent: Int?
    let batteryThresholdPercent: Int
    let cpuLoadPercent: Double?
    let cpuThresholdPercent: Int
    let memoryUsedPercent: Double?
    let memoryThresholdPercent: Int
    let networkActivityBytesPerSecond: Double?
    let networkActivityThresholdBytesPerSecond: Double
    let externalVolumeCount: Int

    static func capture(
        preferences: RunnerPreferences,
        systemMetrics: SystemMetricsSnapshot = .capture(),
        configuredAppRunningProvider: (String) -> Bool = Self.isConfiguredAppRunning,
        externalVolumeCountProvider: () -> Int = Self.externalVolumeCount
    ) -> SleepPreventionTriggerStatus {
        let codexAppRunning = preferences.sleepPreventionCodexAppTriggerEnabled
            ? configuredAppRunningProvider(preferences.sleepPreventionAppMatchText)
            : false
        let externalVolumeCount = preferences.sleepPreventionExternalVolumeTriggerEnabled
            ? externalVolumeCountProvider()
            : 0

        return evaluate(
            preferences: preferences,
            systemMetrics: systemMetrics,
            codexAppRunning: codexAppRunning,
            externalVolumeCount: externalVolumeCount
        )
    }

    static func evaluate(
        preferences: RunnerPreferences,
        systemMetrics: SystemMetricsSnapshot,
        codexAppRunning: Bool,
        externalVolumeCount: Int
    ) -> SleepPreventionTriggerStatus {
        let batteryThreshold = preferences.sleepPreventionBatteryThresholdPercent
        let cpuThreshold = preferences.sleepPreventionCPUThresholdPercent
        let memoryThreshold = preferences.sleepPreventionMemoryThresholdPercent
        let networkThreshold = Double(RunnerPreferences.defaultSleepPreventionNetworkThresholdKBPerSecond) * 1024
        let battery = systemMetrics.battery
        let networkActivityBytesPerSecond = Self.networkActivityBytesPerSecond(systemMetrics)

        return SleepPreventionTriggerStatus(
            powerAdapterTriggerEnabled: preferences.sleepPreventionPowerAdapterTriggerEnabled,
            codexAppTriggerEnabled: preferences.sleepPreventionCodexAppTriggerEnabled,
            chargingBelowThresholdTriggerEnabled: preferences.sleepPreventionChargingBelowThresholdTriggerEnabled,
            cpuThresholdTriggerEnabled: preferences.sleepPreventionCPUThresholdTriggerEnabled,
            memoryThresholdTriggerEnabled: preferences.sleepPreventionMemoryThresholdTriggerEnabled,
            networkActivityTriggerEnabled: preferences.sleepPreventionNetworkActivityTriggerEnabled,
            externalVolumeTriggerEnabled: preferences.sleepPreventionExternalVolumeTriggerEnabled,
            powerAdapterConnected: battery.isConnectedToPower == true,
            codexAppRunning: codexAppRunning,
            appMatchText: preferences.sleepPreventionAppMatchText,
            chargingBelowThreshold: (battery.percent ?? -1) >= batteryThreshold,
            cpuAboveThreshold: (systemMetrics.cpuLoadPercent ?? 0) >= Double(cpuThreshold),
            memoryAboveThreshold: (systemMetrics.memoryUsedPercent ?? 0) >= Double(memoryThreshold),
            networkActivityAboveThreshold: (networkActivityBytesPerSecond ?? 0) >= networkThreshold,
            externalVolumeConnected: externalVolumeCount > 0,
            batteryPercent: battery.percent,
            batteryThresholdPercent: batteryThreshold,
            cpuLoadPercent: systemMetrics.cpuLoadPercent,
            cpuThresholdPercent: cpuThreshold,
            memoryUsedPercent: systemMetrics.memoryUsedPercent,
            memoryThresholdPercent: memoryThreshold,
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
        (memoryThresholdTriggerEnabled && memoryAboveThreshold) ||
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
        memoryThresholdTriggerEnabled ||
        networkActivityTriggerEnabled ||
        externalVolumeTriggerEnabled
    }

    private var matchedLabels: [String] {
        var labels: [String] = []
        if powerAdapterTriggerEnabled && powerAdapterConnected {
            labels.append("전원")
        }
        if codexAppTriggerEnabled && codexAppRunning {
            labels.append("Codex 실행")
        }
        if chargingBelowThresholdTriggerEnabled && chargingBelowThreshold {
            labels.append("배터리 \(batteryThresholdPercent)% 이상")
        }
        if cpuThresholdTriggerEnabled && cpuAboveThreshold {
            labels.append("CPU 사용량")
        }
        if memoryThresholdTriggerEnabled && memoryAboveThreshold {
            labels.append("메모리 사용량")
        }
        if networkActivityTriggerEnabled && networkActivityAboveThreshold {
            labels.append("네트워크 전송")
        }
        if externalVolumeTriggerEnabled && externalVolumeConnected {
            labels.append("드라이브")
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

    private static func isConfiguredAppRunning(matching matchText: String) -> Bool {
        let normalizedMatchText = matchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalizedMatchText.isEmpty else { return false }

        return NSWorkspace.shared.runningApplications.contains { application in
            let bundleIdentifier = application.bundleIdentifier?.lowercased() ?? ""
            let name = application.localizedName?.lowercased() ?? ""
            return bundleIdentifier.contains(normalizedMatchText) || name.contains(normalizedMatchText)
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
