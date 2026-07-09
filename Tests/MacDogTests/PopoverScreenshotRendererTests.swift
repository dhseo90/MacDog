import AppKit
import CodexUsageCore
import SwiftUI
import XCTest
@testable import MacDog

@MainActor
final class PopoverScreenshotRendererTests: XCTestCase {
    func testCodexResetCreditsBlockBuildsCompactLayout() {
        let resetCredits = RateLimitResetCreditsSummary(
            availableCount: 3,
            credits: [
                RateLimitResetCredit(
                    id: "credit_1",
                    status: "available",
                    resetType: "manual",
                    expiresAt: "2027-01-16T09:30:00Z"
                ),
                RateLimitResetCredit(
                    id: "credit_2",
                    status: "available",
                    resetType: "manual",
                    expiresAt: "2027-01-17T11:00:00Z"
                ),
                RateLimitResetCredit(
                    id: "credit_3",
                    status: "available",
                    resetType: "manual",
                    expiresAt: "2027-01-18T12:30:00Z"
                )
            ]
        )

        XCTAssertEqual(CodexResetCreditTextFormatter.countText(for: resetCredits), "3장")
        XCTAssertEqual(
            CodexResetCreditTextFormatter.expirySummary(for: resetCredits, timeZone: TimeZone(secondsFromGMT: 9 * 60 * 60)!),
            "먼저 1/16 18:30까지 · 1/17 20:00까지 · 1/18 21:30까지"
        )
        XCTAssertEqual(
            CodexResetCreditTextFormatter.expiryText(
                for: RateLimitResetCredit(
                    id: "live_credit",
                    status: "available",
                    resetType: "manual",
                    expiresAt: "2026-07-18T00:34:01.707337Z"
                ),
                timeZone: TimeZone(secondsFromGMT: 9 * 60 * 60)!
            ),
            "7/18 09:34까지"
        )

        let view = CodexResetCreditsBlock(resetCredits: resetCredits)

        let hostingView = NSHostingView(rootView: view.frame(width: 320))
        hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 96)
        hostingView.layoutSubtreeIfNeeded()

        XCTAssertLessThanOrEqual(hostingView.fittingSize.height, 96)
    }

    func testCodexResetCreditsBlockKeepsFiveCreditsCompactAndSortedByExpiry() {
        let resetCredits = Self.resetCredits(count: 5, shuffled: true)

        XCTAssertEqual(CodexResetCreditTextFormatter.countText(for: resetCredits), "5장")
        XCTAssertEqual(
            CodexResetCreditTextFormatter.expirySummary(for: resetCredits, timeZone: TimeZone(secondsFromGMT: 9 * 60 * 60)!),
            "먼저 7/18 09:34까지 · 7/27 08:47까지 · 8/1 04:07까지 · 8/5 12:20까지 · 8/9 21:10까지"
        )

        let view = CodexResetCreditsBlock(resetCredits: resetCredits)

        let hostingView = NSHostingView(rootView: view.frame(width: 320))
        hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 96)
        hostingView.layoutSubtreeIfNeeded()

        XCTAssertLessThanOrEqual(hostingView.fittingSize.height, 96)
    }

    func testCodexResetCreditFormatterUsesActionableCopyWhenExpiryDetailsAreUnavailable() {
        let resetCredits = RateLimitResetCreditsSummary(availableCount: 2)

        XCTAssertEqual(CodexResetCreditTextFormatter.countText(for: resetCredits), "2장")
        XCTAssertEqual(
            CodexResetCreditTextFormatter.expirySummary(for: resetCredits),
            "만료일 갱신 필요"
        )
    }

    func testCodexUsagePanelKeepsPrimarySectionsVisibleWithoutDisclosure() throws {
        let state = UsageMonitorState(
            report: Self.codexReportWithThreeResetCreditExpiries(),
            cacheSnapshot: nil,
            weeklyUsageHistory: .empty,
            resetWindowHistory: .empty,
            errorMessage: nil,
            systemMetrics: .unavailable
        )
        let view = CodexUsagePanel(state: state)

        let hostingView = NSHostingView(rootView: view.frame(width: 292))
        hostingView.frame = NSRect(x: 0, y: 0, width: 292, height: 320)
        hostingView.layoutSubtreeIfNeeded()

        XCTAssertLessThanOrEqual(hostingView.fittingSize.height, 320)

        let source = try String(contentsOfFile: "Sources/MacDog/Popover/CodexUsagePanel.swift")
        XCTAssertTrue(
            source.contains("CodexUsageSummaryInline("),
            "Codex tab should keep the existing current risk summary visible"
        )
        XCTAssertTrue(
            source.contains("summary.notificationThresholdSummary"),
            "Codex tab should keep the existing notification threshold visible"
        )
        XCTAssertTrue(
            source.contains("spacing: CodexUsagePanelLayout.sectionSpacing"),
            "Codex tab should separate current usage, reset credits, history, and data status as major sections"
        )
    }

    func testCodexUsagePanelKeepsSixResetCreditsVisibleWithoutDisclosure() throws {
        let state = UsageMonitorState(
            report: Self.codexReportWithResetCredits(Self.resetCredits(count: 6, shuffled: true)),
            cacheSnapshot: nil,
            weeklyUsageHistory: .empty,
            resetWindowHistory: .empty,
            errorMessage: nil,
            systemMetrics: .unavailable
        )
        let view = CodexUsagePanel(state: state)

        let hostingView = NSHostingView(rootView: view.frame(width: 292))
        hostingView.frame = NSRect(x: 0, y: 0, width: 292, height: 320)
        hostingView.layoutSubtreeIfNeeded()

        XCTAssertLessThanOrEqual(hostingView.fittingSize.height, 320)
    }

    func testWeeklyHistoryBlockExposesModePickerAndWiresGraphActions() throws {
        let report = Self.codexReportWithThreeResetCreditExpiries()
        let weeklyWindow = try XCTUnwrap(report.limits["codex"]?.secondary)
        let currentReset = try XCTUnwrap(weeklyWindow.resetsAt)
        let pastReset = currentReset - 604_800
        let history = CodexUsageResetWindowHistory(records: [
            CodexUsageResetWindowHistoryRecord(
                generatedAt: pastReset - 60,
                limitId: "codex",
                windowDurationMins: 10_080,
                resetsAt: pastReset,
                dailyEndSamples: [
                    CodexUsageResetWindowDailySample(
                        dayIndex: 7,
                        recordedAt: pastReset - 60,
                        usedPercent: 72,
                        remainingPercent: 28
                    )
                ],
                finalUsedPercent: 72,
                finalRemainingPercent: 28,
                sampleCount: 1,
                source: .backfill
            )
        ])
        let view = WeeklyRemainingHistoryBlock(
            history: .empty,
            resetWindowHistory: history,
            weeklyWindow: weeklyWindow,
            currentReport: report,
            currentTimestamp: report.generatedAt
        )

        let hostingView = NSHostingView(rootView: view.frame(width: 292))
        hostingView.frame = NSRect(x: 0, y: 0, width: 292, height: 140)
        hostingView.layoutSubtreeIfNeeded()

        let descendants = allDescendants(of: hostingView)
        XCTAssertFalse(
            descendants.contains { $0 is NSSegmentedControl },
            "history mode tabs should avoid the default segmented control chrome"
        )
        XCTAssertEqual(modeTabButtons(in: hostingView).map(\.title), ["현재", "지난", "비교"])
        let source = try String(contentsOfFile: "Sources/MacDog/Popover/WeeklyRemainingHistoryViews.swift")
        XCTAssertTrue(source.contains("graphActionButtons(mode: mode"))
    }

    func testWeeklyHistoryCurrentModeUsesCompactModeControlWithoutWindowPicker() throws {
        let view = try weeklyHistoryBlock(initialMode: .current)
        let hostingView = NSHostingView(rootView: view.frame(width: 292))
        hostingView.frame = NSRect(x: 0, y: 0, width: 292, height: 140)
        hostingView.layoutSubtreeIfNeeded()

        let descendants = allDescendants(of: hostingView)
        let modeTabs = modeTabButtons(in: hostingView)

        XCTAssertEqual(modeTabs.map(\.title), ["현재", "지난", "비교"])
        XCTAssertLessThanOrEqual(modeTabFrame(for: modeTabs, in: hostingView).width, 86)
        XCTAssertFalse(
            descendants.contains { $0 is NSPopUpButton },
            "current mode should not show the past-window dropdown"
        )
    }

    func testWeeklyHistoryPastModeKeepsCompactModeControlAndShowsWindowPicker() throws {
        let view = try weeklyHistoryBlock(initialMode: .past)
        let hostingView = NSHostingView(rootView: view.frame(width: 292))
        hostingView.frame = NSRect(x: 0, y: 0, width: 292, height: 140)
        hostingView.layoutSubtreeIfNeeded()

        let descendants = allDescendants(of: hostingView)
        let modeTabs = modeTabButtons(in: hostingView)
        let windowPicker = try XCTUnwrap(descendants.compactMap { $0 as? NSPopUpButton }.first)
        let modeTabFrame = modeTabFrame(for: modeTabs, in: hostingView)
        let windowPickerFrame = windowPicker.convert(windowPicker.bounds, to: hostingView)

        XCTAssertEqual(modeTabs.map(\.title), ["현재", "지난", "비교"])
        XCTAssertLessThanOrEqual(modeTabFrame.width, 86)
        XCTAssertGreaterThanOrEqual(windowPickerFrame.minX - modeTabFrame.maxX, 24)
        XCTAssertEqual(windowPickerFrame.maxX, hostingView.bounds.maxX, accuracy: 1)
    }

    func testWeeklyHistoryModeSwitchingDoesNotCrashAndCurrentHidesWindowPicker() throws {
        let view = try weeklyHistoryBlock(initialMode: .current)
        let hostingView = NSHostingView(rootView: view.frame(width: 292))
        hostingView.frame = NSRect(x: 0, y: 0, width: 292, height: 140)
        hostingView.layoutSubtreeIfNeeded()

        var descendants = allDescendants(of: hostingView)
        var modeTabs = modeTabButtons(in: hostingView)
        XCTAssertEqual(modeTabs.map(\.title), ["현재", "지난", "비교"])

        modeTabs[1].performClick(nil)
        hostingView.layoutSubtreeIfNeeded()
        descendants = allDescendants(of: hostingView)
        XCTAssertTrue(descendants.contains { $0 is NSPopUpButton })

        modeTabs = modeTabButtons(in: hostingView)
        modeTabs[2].performClick(nil)
        hostingView.layoutSubtreeIfNeeded()
        descendants = allDescendants(of: hostingView)
        XCTAssertTrue(descendants.contains { $0 is NSPopUpButton })

        modeTabs = modeTabButtons(in: hostingView)
        modeTabs[0].performClick(nil)
        hostingView.layoutSubtreeIfNeeded()
        descendants = allDescendants(of: hostingView)
        XCTAssertFalse(descendants.contains { $0 is NSPopUpButton })
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

    func testRenderReadmeCodexComparisonScreenshotWhenRequested() throws {
        guard ProcessInfo.processInfo.environment["MACDOG_RENDER_README_CODEX_COMPARISON"] == "1" else {
            throw XCTSkip("README Codex comparison rendering is opt-in.")
        }

        let outputDirectory = ProcessInfo.processInfo.environment["MACDOG_RENDER_README_CODEX_COMPARISON_OUTPUT_DIR"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent("macdog-readme-codex-comparison", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

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

        let preferences = RunnerPreferences(defaults: defaults)
        let state = MacDogDemoData.state(
            preferences: preferences,
            now: MacDogDemoData.readmeScreenshotTimestamp
        )
        let view = UsagePopoverView(
            state: state,
            notificationAuthorizationClient: StaticUsageNotificationAuthorizationClient(status: .notDetermined)
        )
        let hostingView = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor)))
        hostingView.appearance = NSAppearance(named: .darkAqua)
        hostingView.frame = NSRect(origin: .zero, size: NSSize(width: 370, height: 408))
        hostingView.setFrameSize(NSSize(width: 370, height: 408))
        hostingView.layoutSubtreeIfNeeded()

        let comparisonButton = try XCTUnwrap(
            allDescendants(of: hostingView)
                .compactMap { $0 as? NSButton }
                .first { $0.title == "비교" }
        )
        comparisonButton.performClick(nil)
        hostingView.layoutSubtreeIfNeeded()

        let image = snapshot(hostingView: hostingView, size: NSSize(width: 370, height: 408), scale: 2)
        try write(image: image, to: outputDirectory.appendingPathComponent("macdog-popover-codex-comparison.png"))
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

    private static func codexReportWithThreeResetCreditExpiries() -> CodexUsageReport {
        codexReportWithResetCredits(resetCredits(count: 3, shuffled: false))
    }

    private func weeklyHistoryBlock(
        initialMode: CodexUsageHistoryGraphMode
    ) throws -> WeeklyRemainingHistoryBlock {
        let report = Self.codexReportWithThreeResetCreditExpiries()
        let weeklyWindow = try XCTUnwrap(report.limits["codex"]?.secondary)
        let currentReset = try XCTUnwrap(weeklyWindow.resetsAt)
        let pastReset = currentReset - 604_800
        let history = CodexUsageResetWindowHistory(records: [
            CodexUsageResetWindowHistoryRecord(
                generatedAt: pastReset - 60,
                limitId: "codex",
                windowDurationMins: 10_080,
                resetsAt: pastReset,
                dailyEndSamples: [
                    CodexUsageResetWindowDailySample(
                        dayIndex: 7,
                        recordedAt: pastReset - 60,
                        usedPercent: 72,
                        remainingPercent: 28
                    )
                ],
                finalUsedPercent: 72,
                finalRemainingPercent: 28,
                sampleCount: 1,
                source: .backfill
            )
        ])
        return WeeklyRemainingHistoryBlock(
            history: .empty,
            resetWindowHistory: history,
            weeklyWindow: weeklyWindow,
            currentReport: report,
            currentTimestamp: report.generatedAt,
            initialMode: initialMode
        )
    }

    private static func codexReportWithResetCredits(_ resetCredits: RateLimitResetCreditsSummary) -> CodexUsageReport {
        CodexUsageReport(
            generatedAt: 1_800_000_000,
            source: "test",
            planType: "pro",
            credits: nil,
            resetCredits: resetCredits,
            rateLimitReachedType: nil,
            limits: [
                "codex": UsageLimitReport(
                    limitId: "codex",
                    limitName: "Codex",
                    primary: UsageWindowReport(
                        kind: .fiveHour,
                        usedPercent: 6,
                        remainingPercent: 94,
                        windowDurationMins: 300,
                        resetsAt: 1_800_015_600
                    ),
                    secondary: UsageWindowReport(
                        kind: .weekly,
                        usedPercent: 67,
                        remainingPercent: 33,
                        windowDurationMins: 10_080,
                        resetsAt: 1_800_056_400
                    ),
                    credits: nil,
                    planType: "pro",
                    rateLimitReachedType: nil
                )
            ]
        )
    }

    private static func resetCredits(count: Int, shuffled: Bool) -> RateLimitResetCreditsSummary {
        let expiries = [
            "2026-07-18T00:34:01.707337Z",
            "2026-07-26T23:47:07.735255Z",
            "2026-07-31T19:07:22.221365Z",
            "2026-08-05T03:20:00Z",
            "2026-08-09T12:10:00Z",
            "2026-08-12T14:45:00Z"
        ]
        var credits = Array(expiries.prefix(count)).enumerated().map { index, expiry in
            RateLimitResetCredit(
                id: "credit_\(index + 1)",
                status: "available",
                resetType: "manual",
                expiresAt: expiry
            )
        }

        if shuffled {
            credits = Array(credits.reversed())
        }

        return RateLimitResetCreditsSummary(
            availableCount: count,
            credits: credits
        )
    }

    private func render<V: View>(view: V, size: NSSize, scale: CGFloat) -> NSImage {
        let hostingView = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor)))
        hostingView.appearance = NSAppearance(named: .darkAqua)
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.setFrameSize(size)
        hostingView.layoutSubtreeIfNeeded()

        return snapshot(hostingView: hostingView, size: size, scale: scale)
    }

    private func snapshot(hostingView: NSView, size: NSSize, scale: CGFloat) -> NSImage {
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

    private func allDescendants(of view: NSView) -> [NSView] {
        view.subviews + view.subviews.flatMap(allDescendants)
    }

    private func modeTabButtons(in view: NSView) -> [NSButton] {
        let modeTitles = Set(["현재", "지난", "비교"])
        return allDescendants(of: view)
            .compactMap { $0 as? NSButton }
            .filter { modeTitles.contains($0.title) }
            .sorted { first, second in
                first.convert(first.bounds, to: view).minX < second.convert(second.bounds, to: view).minX
            }
    }

    private func modeTabFrame(for buttons: [NSButton], in view: NSView) -> NSRect {
        buttons
            .map { $0.convert($0.bounds, to: view) }
            .reduce(.null) { $0.union($1) }
    }
}
