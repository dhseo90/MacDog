import AppKit
import CodexUsageCore
import SwiftUI

@MainActor
final class MenuBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: 30)
    private let popover = NSPopover()
    private let cacheStore = CodexUsageCacheStore()
    private var overlayWindow: NSPanel?
    private var overlayButton: NSButton?
    private var preferences = RunnerPreferences()
    private var animationTimer: Timer?
    private var refreshTimer: Timer?
    private var frameIndex = 0
    private var state = UsageMonitorState.empty

    func start() {
        configureStatusItem()
        configureOverlayIfNeeded()
        configurePopover()
        refreshUsage(allowLiveRefresh: false)
        startRefreshTimer()
        restartAnimationTimer()
    }

    private func configureStatusItem() {
        statusItem.autosaveName = "com.dhseo.mycodex.status-item"
        statusItem.isVisible = true

        guard let button = statusItem.button else { return }
        button.image = nil
        button.imagePosition = .noImage
        button.title = "🐕"
        button.target = self
        button.action = #selector(togglePopover)
        button.toolTip = "Codex Usage"
    }

    private func configureOverlayIfNeeded() {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.shouldUseMenuBarOverlay() else { return }
            self.showMenuBarOverlay()
            self.advanceFrame()
        }
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 280, height: 190)
        popover.contentViewController = makePopoverController()
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshUsage(allowLiveRefresh: false)
            }
        }
    }

    private func restartAnimationTimer() {
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: state.phase.frameInterval(reducedMotion: state.reducedMotion), repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advanceFrame()
            }
        }
    }

    private func advanceFrame() {
        frameIndex = (frameIndex + 1) % RunnerIconRenderer.frameCount
        let title = runnerTitle(frame: frameIndex)
        statusItem.button?.attributedTitle = title
        overlayButton?.attributedTitle = title
    }

    private func runnerTitle(frame: Int) -> NSAttributedString {
        let symbol: String
        if state.phase == .limit {
            symbol = "⚠︎"
        } else if state.reducedMotion {
            symbol = "🐕"
        } else {
            symbol = frame % 2 == 0 ? "🐕" : "🐶"
        }

        return NSAttributedString(
            string: symbol,
            attributes: [
                .font: NSFont.systemFont(ofSize: 16),
                .foregroundColor: NSColor.white,
                .baselineOffset: -1
            ]
        )
    }

    private func refreshUsage(allowLiveRefresh: Bool) {
        let previousPhase = state.phase
        let previousPreferences = preferences
        preferences = RunnerPreferences()
        state = loadState(allowLiveRefresh: allowLiveRefresh)
        popover.contentViewController = makePopoverController()
        statusItem.button?.toolTip = state.toolTip
        advanceFrame()

        if previousPhase != state.phase || previousPreferences != preferences {
            restartAnimationTimer()
        }
    }

    private func loadState(allowLiveRefresh: Bool) -> UsageMonitorState {
        if allowLiveRefresh {
            do {
                let report = try CodexUsageService(client: CodexAppServerClient()).readReport()
                try? cacheStore.writeSuccess(report: report)
                return UsageMonitorState(
                    report: report,
                    cacheSnapshot: nil,
                    errorMessage: nil,
                    displayBasis: preferences.displayBasis,
                    reducedMotion: preferences.reducedMotion
                )
            } catch {
                if let snapshot = try? cacheStore.read(), let report = snapshot.report {
                    return UsageMonitorState(
                        report: report,
                        cacheSnapshot: snapshot,
                        errorMessage: error.localizedDescription,
                        displayBasis: preferences.displayBasis,
                        reducedMotion: preferences.reducedMotion
                    )
                }

                return UsageMonitorState(
                    report: nil,
                    cacheSnapshot: nil,
                    errorMessage: error.localizedDescription,
                    displayBasis: preferences.displayBasis,
                    reducedMotion: preferences.reducedMotion
                )
            }
        }

        if let snapshot = try? cacheStore.read(), let report = snapshot.report {
            return UsageMonitorState(
                report: report,
                cacheSnapshot: snapshot,
                errorMessage: snapshot.error?.message,
                displayBasis: preferences.displayBasis,
                reducedMotion: preferences.reducedMotion
            )
        }

        return UsageMonitorState(
            report: nil,
            cacheSnapshot: nil,
            errorMessage: "Usage cache is not available yet.",
            displayBasis: preferences.displayBasis,
            reducedMotion: preferences.reducedMotion
        )
    }

    private func makePopoverController() -> NSViewController {
        NSHostingController(rootView: UsagePopoverView(state: state) {
            Task { @MainActor in
                self.refreshUsage(allowLiveRefresh: true)
            }
        })
    }

    @objc
    private func togglePopover() {
        guard let button = statusItem.button else { return }
        toggleUsagePopover(relativeTo: button)
    }

    @objc
    private func toggleOverlayPopover() {
        guard let button = overlayButton else { return }
        toggleUsagePopover(relativeTo: button)
    }

    private func toggleUsagePopover(relativeTo button: NSView) {
        refreshUsage(allowLiveRefresh: true)

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func shouldUseMenuBarOverlay() -> Bool {
        guard
            let screen = NSScreen.main,
            let auxiliaryTopRightArea = screen.auxiliaryTopRightArea,
            let itemFrame = statusItemScreenFrame()
        else {
            return false
        }

        return itemFrame.maxX < auxiliaryTopRightArea.minX + 48
    }

    private func statusItemScreenFrame() -> NSRect? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    private func showMenuBarOverlay() {
        guard overlayWindow == nil, let screen = NSScreen.main else { return }

        let frame = overlayFrame(on: screen)
        let window = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let button = NSButton(frame: NSRect(origin: .zero, size: frame.size))
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.imagePosition = .noImage
        button.target = self
        button.action = #selector(toggleOverlayPopover)
        button.toolTip = "Codex Usage"
        button.attributedTitle = runnerTitle(frame: frameIndex)

        window.contentView = button
        window.orderFrontRegardless()
        overlayWindow = window
        overlayButton = button
    }

    private func overlayFrame(on screen: NSScreen) -> NSRect {
        let topRightArea = screen.auxiliaryTopRightArea ?? NSRect(
            x: screen.frame.midX,
            y: screen.frame.maxY - 32,
            width: screen.frame.width / 2,
            height: 32
        )
        let size = NSSize(width: 30, height: 24)
        return NSRect(
            x: topRightArea.minX + 12,
            y: screen.frame.maxY - 28,
            width: size.width,
            height: size.height
        )
    }
}
