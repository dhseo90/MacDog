import CodexUsageCore
import Foundation
import MacDogPrivilegedHelperSupport

enum MacDogDemoData {
    static var isEnabled: Bool {
        let value = ProcessInfo.processInfo.environment["MACDOG_DEMO_MODE"]?.lowercased()
        return value == "1" || value == "true" || value == "yes"
    }

    static func state(preferences: RunnerPreferences = RunnerPreferences()) -> UsageMonitorState {
        UsageMonitorState(
            report: report,
            cacheSnapshot: nil,
            errorMessage: nil,
            displayBasis: preferences.displayBasis,
            reducedMotion: preferences.reducedMotion,
            animationPaused: preferences.animationPaused,
            systemMetrics: systemMetrics,
            systemMetricsHistory: systemMetricsHistory,
            sleepPreventionStatus: sleepPreventionStatus(preferences: preferences),
            sleepPreventionTriggerStatus: sleepPreventionTriggerStatus(preferences: preferences),
            privilegedHelperInstallSnapshot: PrivilegedHelperInstallSnapshot(
                helperToolExists: false,
                launchDaemonExists: false
            )
        )
    }

    private static var systemMetricsHistory: SystemMetricsHistory {
        let now = Date()
        let cpuValues: [Double] = [18, 22, 20, 27, 31, 26, 24.9, 29, 34, 28, 25]
        let memoryValues: [Double] = [44, 45.5, 46, 47.8, 48.2, 48.9, 49.1, 49.4, 49.0, 49.6, 49.1]
        let samples = zip(cpuValues.indices, cpuValues).map { index, cpu in
            SystemMetricsHistorySample(
                capturedAt: now.addingTimeInterval(Double(index - cpuValues.count + 1)),
                cpuLoadPercent: cpu,
                memoryUsedPercent: memoryValues[index]
            )
        }
        return SystemMetricsHistory(samples: samples)
    }

    private static var report: CodexUsageReport {
        let now = Int(Date().timeIntervalSince1970)
        let credits = CreditsSnapshot(hasCredits: true, unlimited: false, balance: "12")
        let limit = UsageLimitReport(
            limitId: "codex",
            limitName: "Codex",
            primary: UsageWindowReport(
                kind: .fiveHour,
                usedPercent: 42,
                remainingPercent: 58,
                windowDurationMins: 300,
                resetsAt: now + 7_200
            ),
            secondary: UsageWindowReport(
                kind: .weekly,
                usedPercent: 68,
                remainingPercent: 32,
                windowDurationMins: 10_080,
                resetsAt: now + 345_600
            ),
            credits: credits,
            planType: "pro",
            rateLimitReachedType: nil
        )

        return CodexUsageReport(
            generatedAt: now,
            source: "demo",
            planType: "pro",
            credits: credits,
            rateLimitReachedType: nil,
            limits: ["codex": limit]
        )
    }

    private static var systemMetrics: SystemMetricsSnapshot {
        SystemMetricsSnapshot(
            capturedAt: Date(),
            cpuLoadPercent: 24.9,
            memoryUsedPercent: 49.1,
            memoryDetails: MemoryDetailsSnapshot(
                usedPercent: 49.1,
                appMemoryBytes: 6_100_000_000,
                wiredMemoryBytes: 3_600_000_000,
                compressedMemoryBytes: 3_000_000_000
            ),
            diskUsedPercent: 77.4,
            diskDetails: DiskDetailsSnapshot(
                usedPercent: 77.4,
                usedBytes: 410_598_873_498,
                totalBytes: 530_750_583_603
            ),
            networkReceivedBytes: 2_400_000_000,
            networkSentBytes: 2_000_000_000,
            networkReceivedRateBytesPerSecond: 31_100,
            networkSentRateBytesPerSecond: 352_100,
            activeInterfaceCount: 1,
            primaryNetworkInterfaceName: "Wi-Fi",
            localIPAddress: "192.168.219.112",
            cpuBreakdown: CPUUsageBreakdown(
                userPercent: 16.9,
                systemPercent: 7.9,
                idlePercent: 75.1
            ),
            battery: BatteryStatusSnapshot(
                isPresent: true,
                percent: 94,
                isCharging: false,
                isCharged: false,
                isConnectedToPower: true,
                timeToFullChargeMinutes: nil,
                timeToEmptyMinutes: nil,
                cycleCount: 7,
                temperatureCelsius: 30.1
            ),
            chargeLimitSupport: ChargeLimitSupportSnapshot(
                operatingSystemVersion: OperatingSystemVersion(majorVersion: 26, minorVersion: 4, patchVersion: 0),
                isAppleSilicon: true,
                nativeState: NativeChargeLimitState(
                    isSupported: true,
                    availableLimits: [80, 85, 90, 95, 100],
                    currentLimitPercent: 90,
                    errorMessage: nil
                )
            )
        )
    }

    private static func sleepPreventionStatus(preferences: RunnerPreferences) -> SleepPreventionStatus {
        let triggerStatus = sleepPreventionTriggerStatus(preferences: preferences)
        let isActive = preferences.sleepPreventionEnabled || triggerStatus.isMatched
        return SleepPreventionStatus(
            isEnabled: isActive,
            isActive: isActive,
            endsAt: preferences.sleepPreventionEnabled ? demoEndsAt(preferences: preferences) : nil,
            isClosedLidSleepDisabled: isActive,
            isScreenLockDisabled: isActive,
            errorMessage: nil
        )
    }

    private static func demoEndsAt(preferences: RunnerPreferences) -> Date? {
        if let endsAt = preferences.sleepPreventionEndsAt {
            return endsAt
        }
        guard let durationMinutes = preferences.sleepPreventionSessionPreset.durationMinutes else {
            return nil
        }
        return Date().addingTimeInterval(TimeInterval(durationMinutes * 60))
    }

    private static func sleepPreventionTriggerStatus(preferences: RunnerPreferences) -> SleepPreventionTriggerStatus {
        SleepPreventionTriggerStatus(
            powerAdapterTriggerEnabled: preferences.sleepPreventionPowerAdapterTriggerEnabled,
            codexAppTriggerEnabled: preferences.sleepPreventionCodexAppTriggerEnabled,
            chargingBelowThresholdTriggerEnabled: preferences.sleepPreventionChargingBelowThresholdTriggerEnabled,
            cpuThresholdTriggerEnabled: preferences.sleepPreventionCPUThresholdTriggerEnabled,
            networkActivityTriggerEnabled: preferences.sleepPreventionNetworkActivityTriggerEnabled,
            externalVolumeTriggerEnabled: preferences.sleepPreventionExternalVolumeTriggerEnabled,
            powerAdapterConnected: true,
            codexAppRunning: true,
            chargingBelowThreshold: false,
            cpuAboveThreshold: false,
            networkActivityAboveThreshold: true,
            externalVolumeConnected: false,
            batteryPercent: 94,
            batteryThresholdPercent: RunnerPreferences.sleepPreventionBatteryThresholdPercent,
            cpuLoadPercent: 24.9,
            cpuThresholdPercent: RunnerPreferences.sleepPreventionCPUThresholdPercent,
            networkActivityBytesPerSecond: 383_200,
            networkActivityThresholdBytesPerSecond: RunnerPreferences.sleepPreventionNetworkActivityThresholdBytesPerSecond,
            externalVolumeCount: 0
        )
    }
}
