import AppKit
import CodexUsageCore
import SwiftUI

@MainActor
final class MenuBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private let runnerRenderer = RunnerIconRenderer()
    private let cacheStore = CodexUsageCacheStore()
    private var animationTimer: Timer?
    private var refreshTimer: Timer?
    private var frameIndex = 0
    private var state = UsageMonitorState.empty

    func start() {
        configureStatusItem()
        configurePopover()
        refreshUsage()
        startRefreshTimer()
        restartAnimationTimer()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(togglePopover)
        button.toolTip = "Codex Usage"
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 280, height: 190)
        popover.contentViewController = NSHostingController(rootView: UsagePopoverView(state: state))
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshUsage()
            }
        }
    }

    private func restartAnimationTimer() {
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: state.phase.frameInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advanceFrame()
            }
        }
    }

    private func advanceFrame() {
        frameIndex = (frameIndex + 1) % RunnerIconRenderer.frameCount
        statusItem.button?.image = runnerRenderer.image(frame: frameIndex, phase: state.phase)
    }

    private func refreshUsage() {
        let previousPhase = state.phase
        state = loadState()
        popover.contentViewController = NSHostingController(rootView: UsagePopoverView(state: state))
        statusItem.button?.toolTip = state.toolTip
        advanceFrame()

        if previousPhase != state.phase {
            restartAnimationTimer()
        }
    }

    private func loadState() -> UsageMonitorState {
        if let snapshot = try? cacheStore.read(), let report = snapshot.report {
            return UsageMonitorState(report: report, cacheSnapshot: snapshot, errorMessage: snapshot.error?.message)
        }

        do {
            let report = try CodexUsageService(client: CodexAppServerClient()).readReport()
            return UsageMonitorState(report: report, cacheSnapshot: nil, errorMessage: nil)
        } catch {
            return UsageMonitorState(report: nil, cacheSnapshot: nil, errorMessage: error.localizedDescription)
        }
    }

    @objc
    private func togglePopover() {
        guard let button = statusItem.button else { return }
        refreshUsage()

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}

