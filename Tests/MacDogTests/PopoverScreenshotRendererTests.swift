import AppKit
import CodexUsageCore
import SwiftUI
import XCTest
@testable import MacDog

@MainActor
final class PopoverScreenshotRendererTests: XCTestCase {
    func testCodexRecoveryPlannerBlockBuildsCompactLayout() {
        var selectedDuration = CodexUsageSessionPlanDuration.oneHour
        let entries = [
            CodexUsageResetScheduleEntry(
                id: "codex.fiveHour.1800007200",
                limitId: "codex",
                limitName: "Codex",
                title: "5시간",
                kind: .fiveHour,
                scope: .primary,
                windowDurationMins: 300,
                resetsAt: 1_800_007_200,
                remainingSeconds: 7_200,
                usedPercent: 62,
                remainingPercent: 38,
                trustState: .stale,
                isNextRecovery: true
            ),
            CodexUsageResetScheduleEntry(
                id: "codex.weekly.1800604800",
                limitId: "codex",
                limitName: "Codex",
                title: "주간",
                kind: .weekly,
                scope: .primary,
                windowDurationMins: 10_080,
                resetsAt: 1_800_604_800,
                remainingSeconds: 604_800,
                usedPercent: 41,
                remainingPercent: 59,
                trustState: .stale,
                isNextRecovery: false
            )
        ]
        let schedule = CodexUsageResetSchedule(state: .stale, entries: entries)
        let plan = CodexUsageSessionPlan(
            duration: .oneHour,
            durationSeconds: 3_600,
            state: .watch,
            availability: .ready,
            currentUsedPercent: 62,
            projectedUsedPercentAtEnd: 81,
            usedPercentPerHour: 19,
            sampleCount: 2
        )
        let utc = try! XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let locale = Locale(identifier: "en_US_POSIX")

        XCTAssertEqual(schedule.primaryEntries.count, 2)
        XCTAssertEqual(schedule.primaryEntries.first?.title, "5시간")
        XCTAssertEqual(schedule.primaryEntries.first?.isNextRecovery, true)
        XCTAssertEqual(schedule.primaryEntries.last?.title, "주간")
        XCTAssertEqual(
            CodexRecoveryResetTextFormatter.relativeText(remainingSeconds: entries[0].remainingSeconds),
            "2시간 후"
        )
        XCTAssertEqual(
            CodexRecoveryResetTextFormatter.resetDateText(
                resetsAt: entries[0].resetsAt,
                timeZone: utc,
                locale: locale
            ),
            "1/15 10:00 초기화"
        )
        XCTAssertEqual(
            CodexRecoveryResetTextFormatter.resetDateText(
                resetsAt: entries[1].resetsAt,
                timeZone: utc,
                locale: locale
            ),
            "1/22 08:00 초기화"
        )
        XCTAssertEqual(plan.title, "1시간 작업 주의")
        XCTAssertEqual(plan.detail, "예상 사용률 81%")

        let view = CodexRecoveryPlannerBlock(
            schedule: schedule,
            plan: plan,
            selectedDuration: Binding(
                get: { selectedDuration },
                set: { selectedDuration = $0 }
            )
        )

        let hostingView = NSHostingView(rootView: view.frame(width: 320))
        hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 180)
        hostingView.layoutSubtreeIfNeeded()

        XCTAssertEqual(selectedDuration, .oneHour)
        XCTAssertLessThanOrEqual(hostingView.fittingSize.height, 180)
    }

    func testCodexRecoveryResetFormatterFallsBackWhenResetDateIsUnavailable() {
        XCTAssertEqual(
            CodexRecoveryResetTextFormatter.resetDateText(resetsAt: nil),
            "초기화 시각 확인 불가"
        )
        XCTAssertEqual(
            CodexRecoveryResetTextFormatter.relativeText(remainingSeconds: nil),
            "시각 확인 불가"
        )
    }

    func testRenderReadmeScreenshotsWhenRequested() throws {
        guard ProcessInfo.processInfo.environment["MACDOG_RENDER_README_SCREENSHOTS"] == "1" else {
            throw XCTSkip("README screenshot rendering is opt-in.")
        }

        let outputRoot = ProcessInfo.processInfo.environment["MACDOG_RENDER_README_SCREENSHOTS_OUTPUT_DIR"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Assets", isDirectory: true)
                .appendingPathComponent("Generated", isDirectory: true)
                .appendingPathComponent("Docs", isDirectory: true)
        let outputDirectory = outputRoot.appendingPathComponent("PopoverTabs", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let defaults = UserDefaults.standard
        let keysToRestore = [
            RunnerPreferences.popoverModuleKey,
            RunnerPreferences.sleepPreventionControlModeKey,
            RunnerPreferences.sleepPreventionEnabledKey,
            RunnerPreferences.sleepPreventionSessionPresetKey,
            RunnerPreferences.sleepPreventionEndsAtKey,
            RunnerPreferences.sleepPreventionPowerAdapterTriggerKey,
            RunnerPreferences.sleepPreventionCodexAppTriggerKey,
            RunnerPreferences.sleepPreventionChargingBelowThresholdTriggerKey,
            RunnerPreferences.sleepPreventionCPUThresholdTriggerKey,
            RunnerPreferences.sleepPreventionMemoryThresholdTriggerKey,
            RunnerPreferences.sleepPreventionNetworkActivityTriggerKey,
            RunnerPreferences.sleepPreventionExternalVolumeTriggerKey,
            RunnerPreferences.sleepPreventionBatteryThresholdPercentKey,
            RunnerPreferences.sleepPreventionCPUThresholdPercentKey,
            RunnerPreferences.sleepPreventionMemoryThresholdPercentKey,
            RunnerPreferences.sleepPreventionNetworkThresholdKBPerSecondKey,
            RunnerPreferences.sleepPreventionAppMatchTextKey,
            RunnerPreferences.sleepPreventionPreventDisplaySleepKey,
            RunnerPreferences.sleepPreventionPreventClosedLidSleepKey,
            RunnerPreferences.sleepPreventionDisableScreenLockKey,
            RunnerPreferences.chargeLimitTargetPercentKey,
            RunnerPreferences.loginLaunchEnabledKey,
            RunnerPreferences.usageNotificationsEnabledKey,
            RunnerPreferences.usageResetSoonNotificationsEnabledKey
        ]
        var previousValues: [String: Any] = [:]
        for key in keysToRestore {
            previousValues[key] = defaults.object(forKey: key)
        }

        defer {
            for key in keysToRestore {
                if let value = previousValues[key] {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }

        for module in MacDogPopoverModule.allCases {
            configureDefaults(for: module, defaults: defaults)
            let preferences = RunnerPreferences(defaults: defaults)
            let state = MacDogDemoData.state(
                preferences: preferences,
                now: MacDogDemoData.readmeScreenshotTimestamp
            )
            let view = UsagePopoverView(
                state: state,
                notificationAuthorizationClient: StaticUsageNotificationAuthorizationClient(status: .notDetermined)
            )
            let image = render(view: view, size: NSSize(width: 370, height: 408), scale: 2)
            try write(image: image, to: outputDirectory.appendingPathComponent("macdog-popover-\(module.rawValue).png"))
        }

        let petSource = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent("MacDog", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("DesktopPet", isDirectory: true)
            .appendingPathComponent("pup-idle-front-0.png")
        let petDestination = outputRoot.appendingPathComponent("macdog-desktop-pet-front.png")
        if FileManager.default.fileExists(atPath: petDestination.path) {
            try FileManager.default.removeItem(at: petDestination)
        }
        try FileManager.default.copyItem(at: petSource, to: petDestination)
    }

    func testRenderLiveCodexPopoverScreenshotWhenRequested() throws {
        guard ProcessInfo.processInfo.environment["MACDOG_RENDER_LIVE_CODEX_POPOVER"] == "1" else {
            throw XCTSkip("Live Codex popover rendering is opt-in.")
        }

        let outputDirectory = ProcessInfo.processInfo.environment["MACDOG_RENDER_LIVE_CODEX_POPOVER_OUTPUT_DIR"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent("macdog-live-popover", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let cacheSnapshot = try CodexUsageCacheStore().read()
        let weeklyHistory = (try? CodexUsageWeeklyHistoryStore().read()) ?? .empty
        let resetWindowHistory = (try? CodexUsageResetWindowHistoryStore().read()) ?? .empty
        guard let report = cacheSnapshot.report else {
            XCTFail("Live cache snapshot has no usage report.")
            return
        }

        let defaults = UserDefaults.standard
        let previousModule = defaults.object(forKey: RunnerPreferences.popoverModuleKey)
        defer {
            if let previousModule {
                defaults.set(previousModule, forKey: RunnerPreferences.popoverModuleKey)
            } else {
                defaults.removeObject(forKey: RunnerPreferences.popoverModuleKey)
            }
        }
        defaults.set(MacDogPopoverModule.codex.rawValue, forKey: RunnerPreferences.popoverModuleKey)

        let state = UsageMonitorState(
            report: report,
            cacheSnapshot: cacheSnapshot,
            weeklyUsageHistory: weeklyHistory,
            resetWindowHistory: resetWindowHistory,
            errorMessage: cacheSnapshot.error?.message,
            systemMetrics: .unavailable
        )
        let view = UsagePopoverView(
            state: state,
            notificationAuthorizationClient: StaticUsageNotificationAuthorizationClient(status: .notDetermined)
        )
        let image = render(view: view, size: NSSize(width: 370, height: 408), scale: 2)
        try write(image: image, to: outputDirectory.appendingPathComponent("macdog-popover-live-codex.png"))
    }

    private func configureDefaults(for module: MacDogPopoverModule, defaults: UserDefaults) {
        RunnerPreferences.setSleepPreventionControlMode(.off, defaults: defaults)
        defaults.set(module.rawValue, forKey: RunnerPreferences.popoverModuleKey)

        if module == .sleep {
            RunnerPreferences.setSleepPreventionControlMode(.condition, defaults: defaults)
            RunnerPreferences.setSleepPreventionPowerAdapterTrigger(true, defaults: defaults)
            RunnerPreferences.setSleepPreventionCodexAppTrigger(true, defaults: defaults)
            RunnerPreferences.setSleepPreventionChargingBelowThresholdTrigger(true, defaults: defaults)
            RunnerPreferences.setSleepPreventionMemoryThresholdTrigger(true, defaults: defaults)
            RunnerPreferences.setSleepPreventionNetworkActivityTrigger(true, defaults: defaults)
            RunnerPreferences.setSleepPreventionBatteryThresholdPercent(
                RunnerPreferences.defaultSleepPreventionBatteryThresholdPercent,
                defaults: defaults
            )
            RunnerPreferences.setSleepPreventionCPUThresholdPercent(
                RunnerPreferences.defaultSleepPreventionCPUThresholdPercent,
                defaults: defaults
            )
            RunnerPreferences.setSleepPreventionMemoryThresholdPercent(
                RunnerPreferences.defaultSleepPreventionMemoryThresholdPercent,
                defaults: defaults
            )
            RunnerPreferences.setSleepPreventionNetworkThresholdKBPerSecond(256, defaults: defaults)
            RunnerPreferences.setSleepPreventionAppMatchText("Codex", defaults: defaults)
        }

        if module == .settings {
            RunnerPreferences.setDesktopPetEnabled(true, defaults: defaults)
            RunnerPreferences.setReducedMotion(false, defaults: defaults)
            RunnerPreferences.setAnimationPaused(false, defaults: defaults)
            RunnerPreferences.setLoginLaunchEnabled(true, defaults: defaults)
            RunnerPreferences.setUsageNotificationsEnabled(false, defaults: defaults)
            RunnerPreferences.setUsageResetSoonNotificationsEnabled(true, defaults: defaults)
        }

        if module == .battery {
            RunnerPreferences.setChargeLimitTargetPercent(90, defaults: defaults)
        }
    }

    private func render<V: View>(view: V, size: NSSize, scale: CGFloat) -> NSImage {
        let hostingView = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor)))
        hostingView.appearance = NSAppearance(named: .darkAqua)
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.setFrameSize(size)
        hostingView.layoutSubtreeIfNeeded()

        let pixelWidth = Int(size.width * scale)
        let pixelHeight = Int(size.height * scale)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            fatalError("Failed to allocate screenshot bitmap")
        }
        bitmap.size = size

        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)

        let image = NSImage(size: size)
        image.addRepresentation(bitmap)
        return image
    }

    private func write(image: NSImage, to url: URL) throws {
        guard
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let png = bitmap.representation(using: .png, properties: [:])
        else {
            XCTFail("Failed to encode screenshot at \(url.path)")
            return
        }

        try png.write(to: url)
    }
}
