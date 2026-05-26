import AppKit
import CodexUsageCore
import SwiftUI

@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: 38)
    private let popover = NSPopover()
    private let runnerRenderer = RunnerIconRenderer()
    private let cacheStore = CodexUsageCacheStore()
    private var preferences = RunnerPreferences()
    private var animationTimer: Timer?
    private var refreshTimer: Timer?
    private var liveRefreshTask: Task<Void, Never>?
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private var frameIndex = 0
    private var state = UsageMonitorState.empty

    func start() {
        configureStatusItem()
        configurePopover()
        refreshUsage(allowLiveRefresh: false)
        startRefreshTimer()
        restartAnimationTimer()
    }

    private func configureStatusItem() {
        statusItem.autosaveName = "com.dhseo.mycodex.status-item"
        statusItem.isVisible = true

        guard let button = statusItem.button else { return }
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.target = self
        button.action = #selector(togglePopover)
        button.toolTip = "Codex Usage"
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 280, height: 310)
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
        let image = runnerRenderer.image(
            frame: frameIndex,
            phase: state.phase,
            reducedMotion: state.reducedMotion
        )
        statusItem.button?.image = image
    }

    private func refreshUsage(allowLiveRefresh: Bool) {
        let previousPhase = state.phase
        let previousPreferences = preferences
        preferences = RunnerPreferences()
        applyState(loadCachedState())

        if previousPhase != state.phase || previousPreferences != preferences {
            restartAnimationTimer()
        }

        if allowLiveRefresh {
            requestLiveRefresh()
        }
    }

    private func applyState(_ newState: UsageMonitorState) {
        state = newState
        popover.contentViewController = makePopoverController()
        statusItem.button?.toolTip = state.toolTip
        advanceFrame()
    }

    private func loadCachedState(errorMessage: String? = nil) -> UsageMonitorState {
        if let snapshot = try? cacheStore.read(), let report = snapshot.report {
            return UsageMonitorState(
                report: report,
                cacheSnapshot: snapshot,
                errorMessage: errorMessage ?? snapshot.error?.message,
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

    private func requestLiveRefresh() {
        liveRefreshTask?.cancel()
        applyState(state.withRefreshing(true))
        liveRefreshTask = Task { [weak self] in
            let result = await Self.fetchLiveUsage()
            guard !Task.isCancelled, let self else { return }
            let previousPhase = self.state.phase
            let previousPreferences = self.preferences
            self.preferences = RunnerPreferences()
            self.applyState(self.state(from: result))
            self.liveRefreshTask = nil

            if previousPhase != self.state.phase || previousPreferences != self.preferences {
                self.restartAnimationTimer()
            }
        }
    }

    private func cancelLiveRefresh() {
        liveRefreshTask?.cancel()
        liveRefreshTask = nil

        if state.isRefreshing {
            applyState(loadCachedState())
        }
    }

    nonisolated private static func fetchLiveUsage() async -> LiveUsageRefreshResult {
        await Task.detached(priority: .userInitiated) {
            let cacheStore = CodexUsageCacheStore()

            do {
                let report = try CodexUsageService(client: CodexAppServerClient()).readReport()
                try? cacheStore.writeSuccess(report: report)
                return .success(report)
            } catch {
                return .failure(
                    message: error.localizedDescription,
                    cachedSnapshot: try? cacheStore.read()
                )
            }
        }.value
    }

    private func state(from result: LiveUsageRefreshResult) -> UsageMonitorState {
        switch result {
        case .success(let report):
            UsageMonitorState(
                report: report,
                cacheSnapshot: nil,
                errorMessage: nil,
                displayBasis: preferences.displayBasis,
                reducedMotion: preferences.reducedMotion
            )
        case .failure(let message, let snapshot):
            if let snapshot, let report = snapshot.report {
                UsageMonitorState(
                    report: report,
                    cacheSnapshot: snapshot,
                    errorMessage: message,
                    displayBasis: preferences.displayBasis,
                    reducedMotion: preferences.reducedMotion
                )
            } else {
                UsageMonitorState(
                    report: nil,
                    cacheSnapshot: nil,
                    errorMessage: message,
                    displayBasis: preferences.displayBasis,
                    reducedMotion: preferences.reducedMotion
                )
            }
        }
    }

    private func makePopoverController() -> NSViewController {
        NSHostingController(rootView: UsagePopoverView(state: state) {
            Task { @MainActor in
                self.refreshUsage(allowLiveRefresh: false)
            }
        })
    }

    @objc
    private func togglePopover() {
        guard let button = statusItem.button else { return }
        toggleUsagePopover(relativeTo: button)
    }

    func showUsagePopover() {
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)

        if popover.isShown {
            requestLiveRefresh()
            return
        }

        showUsagePopover(relativeTo: button)
    }

    private func toggleUsagePopover(relativeTo button: NSView) {
        if popover.isShown {
            popover.performClose(nil)
            return
        }

        showUsagePopover(relativeTo: button)
    }

    private func showUsagePopover(relativeTo button: NSView) {
        refreshUsage(allowLiveRefresh: false)
        installOutsideClickMonitors()
        popover.show(relativeTo: popoverAnchorRect(in: button), of: button, preferredEdge: .maxY)
        positionPopoverWindow(under: button)
        requestLiveRefresh()
    }

    nonisolated func popoverDidClose(_ notification: Notification) {
        Task { @MainActor in
            self.cancelLiveRefresh()
            self.removeOutsideClickMonitors()
        }
    }

    private func popoverAnchorRect(in button: NSView) -> NSRect {
        let width = min(button.bounds.width, 24)
        return NSRect(
            x: (button.bounds.width - width) / 2,
            y: button.bounds.minY,
            width: width,
            height: button.bounds.height
        )
    }

    private func installOutsideClickMonitors() {
        removeOutsideClickMonitors()

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            Task { @MainActor in
                self?.closePopoverIfNeeded(for: event)
            }
            return event
        }

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            Task { @MainActor in
                self?.closePopoverIfNeeded(for: event)
            }
        }
    }

    private func removeOutsideClickMonitors() {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }

        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
            self.globalEventMonitor = nil
        }
    }

    private func closePopoverIfNeeded(for event: NSEvent) {
        guard popover.isShown else { return }

        let point = screenPoint(for: event)
        guard !isPointInPopover(point), !isPointInStatusItem(point) else { return }
        popover.performClose(nil)
    }

    private func screenPoint(for event: NSEvent) -> NSPoint {
        guard let window = event.window else {
            return NSEvent.mouseLocation
        }

        return window.convertToScreen(NSRect(origin: event.locationInWindow, size: .zero)).origin
    }

    private func isPointInPopover(_ point: NSPoint) -> Bool {
        guard let window = popover.contentViewController?.view.window else { return false }
        return window.frame.insetBy(dx: -4, dy: -4).contains(point)
    }

    private func isPointInStatusItem(_ point: NSPoint) -> Bool {
        guard let button = statusItem.button, let window = button.window else { return false }
        let frame = window.convertToScreen(button.convert(button.bounds, to: nil))
        return frame.insetBy(dx: -4, dy: -4).contains(point)
    }

    private func positionPopoverWindow(under button: NSView) {
        guard
            let popoverWindow = popover.contentViewController?.view.window,
            let buttonWindow = button.window,
            let screen = buttonWindow.screen ?? NSScreen.main
        else { return }

        let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screenFrame = screen.visibleFrame
        var frame = popoverWindow.frame
        frame.origin.x = buttonFrame.midX - frame.width / 2
        frame.origin.x = min(max(frame.origin.x, screenFrame.minX + 8), screenFrame.maxX - frame.width - 8)
        frame.origin.y = max(screenFrame.minY + 8, buttonFrame.minY - frame.height - 4)
        popoverWindow.setFrame(frame, display: true)
    }
}

private enum LiveUsageRefreshResult: Sendable {
    case success(CodexUsageReport)
    case failure(message: String, cachedSnapshot: CodexUsageCacheSnapshot?)
}
