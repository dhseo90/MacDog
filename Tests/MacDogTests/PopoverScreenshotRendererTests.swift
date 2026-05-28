import AppKit
import SwiftUI
import XCTest
@testable import MacDog

@MainActor
final class PopoverScreenshotRendererTests: XCTestCase {
    func testRenderReadmeScreenshotsWhenRequested() throws {
        guard ProcessInfo.processInfo.environment["MACDOG_RENDER_README_SCREENSHOTS"] == "1" else {
            throw XCTSkip("README screenshot rendering is opt-in.")
        }

        let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Assets", isDirectory: true)
            .appendingPathComponent("Generated", isDirectory: true)
            .appendingPathComponent("Docs", isDirectory: true)
            .appendingPathComponent("PopoverTabs", isDirectory: true)
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
            RunnerPreferences.sleepPreventionNetworkActivityTriggerKey,
            RunnerPreferences.sleepPreventionExternalVolumeTriggerKey,
            RunnerPreferences.sleepPreventionBatteryThresholdPercentKey,
            RunnerPreferences.sleepPreventionCPUThresholdPercentKey,
            RunnerPreferences.sleepPreventionNetworkThresholdKBPerSecondKey,
            RunnerPreferences.sleepPreventionAppMatchTextKey,
            RunnerPreferences.chargeLimitTargetPercentKey
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
            let state = MacDogDemoData.state(preferences: preferences)
            let view = UsagePopoverView(state: state)
            let image = render(view: view, size: NSSize(width: 370, height: 408), scale: 2)
            try write(image: image, to: outputDirectory.appendingPathComponent("macdog-popover-\(module.rawValue).png"))
        }

        let petSource = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent("MacDog", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("DesktopPet", isDirectory: true)
            .appendingPathComponent("pup-idle-front-0.png")
        let petDestination = outputDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("macdog-desktop-pet-front.png")
        if FileManager.default.fileExists(atPath: petDestination.path) {
            try FileManager.default.removeItem(at: petDestination)
        }
        try FileManager.default.copyItem(at: petSource, to: petDestination)
    }

    private func configureDefaults(for module: MacDogPopoverModule, defaults: UserDefaults) {
        RunnerPreferences.setSleepPreventionControlMode(.off, defaults: defaults)
        defaults.set(module.rawValue, forKey: RunnerPreferences.popoverModuleKey)

        if module == .sleep {
            RunnerPreferences.setSleepPreventionControlMode(.condition, defaults: defaults)
            RunnerPreferences.setSleepPreventionPowerAdapterTrigger(true, defaults: defaults)
            RunnerPreferences.setSleepPreventionCodexAppTrigger(true, defaults: defaults)
            RunnerPreferences.setSleepPreventionChargingBelowThresholdTrigger(true, defaults: defaults)
            RunnerPreferences.setSleepPreventionNetworkActivityTrigger(true, defaults: defaults)
            RunnerPreferences.setSleepPreventionBatteryThresholdPercent(90, defaults: defaults)
            RunnerPreferences.setSleepPreventionCPUThresholdPercent(75, defaults: defaults)
            RunnerPreferences.setSleepPreventionNetworkThresholdKBPerSecond(256, defaults: defaults)
            RunnerPreferences.setSleepPreventionAppMatchText("Codex", defaults: defaults)
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
