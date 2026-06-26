import CodexUsageCore
import Foundation
import MacDogPrivilegedHelperSupport

enum MacDogDemoData {
    static let readmeScreenshotTimestamp = 1_780_401_600
    static let readmeScreenshotWeeklyResetTimestamp = 1_780_876_800

    static var isEnabled: Bool {
        let value = ProcessInfo.processInfo.environment["MACDOG_DEMO_MODE"]?.lowercased()
        return value == "1" || value == "true" || value == "yes"
    }

    static func state(
        preferences: RunnerPreferences = RunnerPreferences(),
        now: Int = Int(Date().timeIntervalSince1970)
    ) -> UsageMonitorState {
        return UsageMonitorState(
            report: report(now: now),
            cacheSnapshot: nil,
            weeklyUsageHistory: weeklyUsageHistory(now: now),
            resetWindowHistory: resetWindowHistory(now: now),
            errorMessage: nil,
            displayBasis: preferences.displayBasis,
            reducedMotion: preferences.reducedMotion,
            animationPaused: preferences.animationPaused,
            systemMetrics: systemMetrics,
            systemMetricsHistory: systemMetricsHistory,
            sleepPreventionStatus: sleepPreventionStatus(preferences: preferences, now: now),
            sleepPreventionTriggerStatus: sleepPreventionTriggerStatus(preferences: preferences),
            privilegedHelperInstallSnapshot: PrivilegedHelperInstallSnapshot(
                helperToolExists: false,
                launchDaemonExists: false
            )
        )
    }

    private static var systemMetricsHistory: SystemMetricsHistory {
        let now = Date()
        let cpuValues: [Double] = [18, 22, 20, 27, 31, 26, 24.9, 29, 34, 28, 24.9]
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

    private static func report(now: Int) -> CodexUsageReport {
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
                usedPercent: 100 - weeklyRemainingPercent(now: now),
                remainingPercent: weeklyRemainingPercent(now: now),
                windowDurationMins: 10_080,
                resetsAt: weeklyResetTimestamp(now: now)
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

    private static func weeklyUsageHistory(now: Int) -> CodexUsageWeeklyHistory {
        let resetsAt = weeklyResetTimestamp(now: now)
        let windowDurationMins = 10_080
        let start = resetsAt - (windowDurationMins * 60)
        let currentFraction = Double(now - start) / Double(windowDurationMins * 60)
        let baseProgress = weeklyBaseProgress(now: now)
        let progress = baseProgress.filter { $0.0 < currentFraction } + [(currentFraction, weeklyRemainingPercent(now: now))]
        let samples = progress.map { fraction, remaining in
            CodexUsageWeeklyHistorySample(
                recordedAt: start + Int(Double(windowDurationMins * 60) * min(max(fraction, 0), 1)),
                usedPercent: 100 - remaining,
                remainingPercent: remaining,
                resetsAt: resetsAt,
                windowDurationMins: windowDurationMins
            )
        }
        return CodexUsageWeeklyHistory(samples: samples)
    }

    private static func resetWindowHistory(now: Int) -> CodexUsageResetWindowHistory {
        let currentReset = weeklyResetTimestamp(now: now)
        let durationSeconds = 10_080 * 60
        let pastWindows = [
            (resetsAt: currentReset - durationSeconds, used: [8.0, 16.0, 25.0, 37.0, 48.0, 60.0, 72.0]),
            (resetsAt: currentReset - 2 * durationSeconds, used: [6.0, 14.0, 21.0, 31.0, 39.0, 46.0, 54.0])
        ]
        let records = pastWindows.map { window in
            let samples = window.used.enumerated().map { index, usedPercent in
                CodexUsageResetWindowDailySample(
                    dayIndex: index + 1,
                    recordedAt: window.resetsAt - (6 - index) * 86_400,
                    usedPercent: usedPercent,
                    remainingPercent: 100 - usedPercent
                )
            }
            let finalUsed = window.used.last ?? 0
            return CodexUsageResetWindowHistoryRecord(
                generatedAt: window.resetsAt - 60,
                limitId: "codex",
                windowDurationMins: 10_080,
                resetsAt: window.resetsAt,
                dailyEndSamples: samples,
                finalUsedPercent: finalUsed,
                finalRemainingPercent: 100 - finalUsed,
                sampleCount: samples.count,
                source: .importedSummary
            )
        }

        return CodexUsageResetWindowHistory(records: records)
    }

    private static func weeklyResetTimestamp(now: Int) -> Int {
        if now == readmeScreenshotTimestamp {
            return readmeScreenshotWeeklyResetTimestamp
        }
        return now + 345_600
    }

    private static func weeklyRemainingPercent(now: Int) -> Double {
        now == readmeScreenshotTimestamp ? 93 : 32
    }

    private static func weeklyBaseProgress(now: Int) -> [(Double, Double)] {
        if now == readmeScreenshotTimestamp {
            return [
                (0.00, 100),
                (0.08, 98),
                (0.14, 96)
            ]
        }

        return [
            (0.00, 100),
            (0.10, 94),
            (0.22, 86),
            (0.36, 72)
        ]
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

    private static func sleepPreventionStatus(preferences: RunnerPreferences, now: Int) -> SleepPreventionStatus {
        let triggerStatus = sleepPreventionTriggerStatus(preferences: preferences)
        let isActive = preferences.sleepPreventionEnabled || triggerStatus.isMatched
        return SleepPreventionStatus(
            isEnabled: isActive,
            isActive: isActive,
            endsAt: preferences.sleepPreventionEnabled ? demoEndsAt(preferences: preferences, now: now) : nil,
            isClosedLidSleepDisabled: isActive && preferences.sleepPreventionPreventClosedLidSleep,
            isScreenLockDisabled: isActive && preferences.sleepPreventionDisableScreenLock,
            errorMessage: nil,
            closedLidWarningMessage: nil,
            screenLockWarningMessage: nil
        )
    }

    private static func demoEndsAt(preferences: RunnerPreferences, now: Int) -> Date? {
        if let endsAt = preferences.sleepPreventionEndsAt {
            return endsAt
        }
        guard let durationMinutes = preferences.sleepPreventionSessionPreset.durationMinutes else {
            return nil
        }
        return Date(timeIntervalSince1970: TimeInterval(now + durationMinutes * 60))
    }

    private static func sleepPreventionTriggerStatus(preferences: RunnerPreferences) -> SleepPreventionTriggerStatus {
        SleepPreventionTriggerStatus(
            powerAdapterTriggerEnabled: preferences.sleepPreventionPowerAdapterTriggerEnabled,
            codexAppTriggerEnabled: preferences.sleepPreventionCodexAppTriggerEnabled,
            chargingBelowThresholdTriggerEnabled: preferences.sleepPreventionChargingBelowThresholdTriggerEnabled,
            cpuThresholdTriggerEnabled: preferences.sleepPreventionCPUThresholdTriggerEnabled,
            memoryThresholdTriggerEnabled: preferences.sleepPreventionMemoryThresholdTriggerEnabled,
            networkActivityTriggerEnabled: preferences.sleepPreventionNetworkActivityTriggerEnabled,
            externalVolumeTriggerEnabled: preferences.sleepPreventionExternalVolumeTriggerEnabled,
            powerAdapterConnected: true,
            codexAppRunning: true,
            appMatchText: preferences.sleepPreventionAppMatchText,
            chargingBelowThreshold: true,
            cpuAboveThreshold: false,
            memoryAboveThreshold: false,
            networkActivityAboveThreshold: true,
            externalVolumeConnected: false,
            batteryPercent: 94,
            batteryThresholdPercent: preferences.sleepPreventionBatteryThresholdPercent,
            cpuLoadPercent: 24.9,
            cpuThresholdPercent: preferences.sleepPreventionCPUThresholdPercent,
            memoryUsedPercent: 49.1,
            memoryThresholdPercent: preferences.sleepPreventionMemoryThresholdPercent,
            networkActivityBytesPerSecond: 383_200,
            networkActivityThresholdBytesPerSecond: Double(RunnerPreferences.defaultSleepPreventionNetworkThresholdKBPerSecond) * 1024,
            externalVolumeCount: 0
        )
    }
}
