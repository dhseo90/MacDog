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
    private var floatingPetController: FloatingPetController?
    private var frameIndex = 0
    private var state = UsageMonitorState.empty

    func start() {
        configureStatusItem()
        configurePopover()
        refreshUsage(allowLiveRefresh: false)
        startRefreshTimer()
        restartAnimationTimer()
        syncDesktopPetVisibility()
    }

    private func configureStatusItem() {
        statusItem.autosaveName = "com.dhseo.macdog.status-item"
        statusItem.isVisible = true

        guard let button = statusItem.button else { return }
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.target = self
        button.action = #selector(statusItemActivated)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "MacDog"
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: 300, height: 430)
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
        animationTimer = nil

        guard !state.animationPaused else {
            renderCurrentFrame()
            return
        }

        animationTimer = Timer.scheduledTimer(withTimeInterval: state.phase.frameInterval(reducedMotion: state.reducedMotion), repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advanceFrame()
            }
        }
    }

    private func advanceFrame() {
        frameIndex = (frameIndex + 1) % RunnerIconRenderer.frameCount
        renderCurrentFrame()
    }

    private func renderCurrentFrame() {
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

        syncDesktopPetVisibility()

        if allowLiveRefresh {
            requestLiveRefresh()
        }
    }

    private func applyState(_ newState: UsageMonitorState) {
        state = newState
        popover.contentViewController = makePopoverController()
        statusItem.button?.toolTip = state.toolTip
        renderCurrentFrame()
    }

    private func loadCachedState(errorMessage: String? = nil) -> UsageMonitorState {
        if let snapshot = try? cacheStore.read(), let report = snapshot.report {
            return UsageMonitorState(
                report: report,
                cacheSnapshot: snapshot,
                errorMessage: errorMessage ?? snapshot.error?.message,
                displayBasis: preferences.displayBasis,
                reducedMotion: preferences.reducedMotion,
                animationPaused: preferences.animationPaused
            )
        }

        return UsageMonitorState(
            report: nil,
            cacheSnapshot: nil,
            errorMessage: "사용량 캐시가 아직 없습니다.",
            displayBasis: preferences.displayBasis,
            reducedMotion: preferences.reducedMotion,
            animationPaused: preferences.animationPaused
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

            self.syncDesktopPetVisibility()
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
                reducedMotion: preferences.reducedMotion,
                animationPaused: preferences.animationPaused
            )
        case .failure(let message, let snapshot):
            if let snapshot, let report = snapshot.report {
                UsageMonitorState(
                    report: report,
                    cacheSnapshot: snapshot,
                    errorMessage: message,
                    displayBasis: preferences.displayBasis,
                    reducedMotion: preferences.reducedMotion,
                    animationPaused: preferences.animationPaused
                )
            } else {
                UsageMonitorState(
                    report: nil,
                    cacheSnapshot: nil,
                    errorMessage: message,
                    displayBasis: preferences.displayBasis,
                    reducedMotion: preferences.reducedMotion,
                    animationPaused: preferences.animationPaused
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

    private func perform(_ action: PetAction) {
        switch action {
        case .showUsageDetails:
            showUsagePopover()
        case .refreshNow:
            refreshUsage(allowLiveRefresh: true)
        case .setDisplayBasis(let basis):
            RunnerPreferences.setDisplayBasis(basis)
            refreshUsage(allowLiveRefresh: false)
        case .setReducedMotion(let isEnabled):
            RunnerPreferences.setReducedMotion(isEnabled)
            refreshUsage(allowLiveRefresh: false)
        case .setAnimationPaused(let isPaused):
            RunnerPreferences.setAnimationPaused(isPaused)
            refreshUsage(allowLiveRefresh: false)
        case .showDesktopPet:
            RunnerPreferences.setDesktopPetEnabled(true)
            refreshUsage(allowLiveRefresh: false)
        case .returnToMenuBar:
            RunnerPreferences.setDesktopPetEnabled(false)
            refreshUsage(allowLiveRefresh: false)
        case .quit:
            NSApp.terminate(nil)
        }
    }

    @objc
    private func statusItemActivated() {
        guard let button = statusItem.button else { return }

        if NSApp.currentEvent?.type == .rightMouseUp {
            showPetMenu(relativeTo: button, surface: .menuBar)
            return
        }

        if popover.isShown {
            popover.performClose(nil)
            return
        }

        perform(.showUsageDetails)
    }

    private func showPetMenu(relativeTo button: NSView, surface: PetSurface) {
        preferences = RunnerPreferences()
        let menu = makePetMenu(surface: surface)
        menu.popUp(positioning: nil, at: NSPoint(x: button.bounds.midX, y: button.bounds.minY), in: button)
    }

    private func makePetMenu(surface: PetSurface) -> NSMenu {
        let menu = NSMenu(title: "코덱스 펫")
        menu.addItem(menuItem("사용량 상세 보기", action: #selector(menuShowUsageDetails)))
        menu.addItem(menuItem("지금 새로고침", action: #selector(menuRefreshNow)))
        menu.addItem(.separator())
        menu.addItem(speedSubmenuItem())
        menu.addItem(menuItem(
            "움직임 줄이기",
            action: #selector(menuToggleReduceMotion),
            state: preferences.reducedMotion ? .on : .off
        ))
        menu.addItem(menuItem(
            "애니메이션 일시 정지",
            action: #selector(menuToggleAnimationPaused),
            state: preferences.animationPaused ? .on : .off
        ))
        menu.addItem(.separator())
        menu.addItem(desktopSurfaceMenuItem(surface: surface))
        menu.addItem(.separator())
        menu.addItem(menuItem("코덱스 사용량 종료", action: #selector(menuQuit)))
        return menu
    }

    private func speedSubmenuItem() -> NSMenuItem {
        let parent = NSMenuItem(title: "러너 속도", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "러너 속도")

        for basis in UsageDisplayBasis.allCases {
            let item = menuItem(
                basis.label,
                action: #selector(menuSetDisplayBasis),
                state: preferences.displayBasis == basis ? .on : .off,
                representedObject: basis.rawValue
            )
            submenu.addItem(item)
        }

        parent.submenu = submenu
        return parent
    }

    private func desktopSurfaceMenuItem(surface: PetSurface) -> NSMenuItem {
        if preferences.desktopPetEnabled || surface == .desktop {
            return menuItem("메뉴바로 돌아가기", action: #selector(menuReturnToMenuBar))
        }

        return menuItem("데스크톱 펫 보기", action: #selector(menuShowDesktopPet))
    }

    private func menuItem(
        _ title: String,
        action: Selector,
        state: NSControl.StateValue = .off,
        representedObject: Any? = nil
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = state
        item.representedObject = representedObject
        return item
    }

    @objc
    private func menuShowUsageDetails() {
        perform(.showUsageDetails)
    }

    @objc
    private func menuRefreshNow() {
        perform(.refreshNow)
    }

    @objc
    private func menuSetDisplayBasis(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let basis = UsageDisplayBasis(rawValue: rawValue)
        else { return }

        perform(.setDisplayBasis(basis))
    }

    @objc
    private func menuToggleReduceMotion() {
        perform(.setReducedMotion(!preferences.reducedMotion))
    }

    @objc
    private func menuToggleAnimationPaused() {
        perform(.setAnimationPaused(!preferences.animationPaused))
    }

    @objc
    private func menuShowDesktopPet() {
        perform(.showDesktopPet)
    }

    @objc
    private func menuReturnToMenuBar() {
        perform(.returnToMenuBar)
    }

    @objc
    private func menuQuit() {
        perform(.quit)
    }

    private func syncDesktopPetVisibility() {
        if preferences.desktopPetEnabled {
            let controller = desktopPetController()
            controller.update(state: state)
            controller.show()
        } else {
            floatingPetController?.hide()
        }
    }

    private func desktopPetController() -> FloatingPetController {
        if let floatingPetController {
            return floatingPetController
        }

        let controller = FloatingPetController(
            actionHandler: { [weak self] action in
                Task { @MainActor in
                    self?.perform(action)
                }
            },
            menuProvider: { [weak self] surface in
                guard let self else { return NSMenu(title: "코덱스 펫") }
                self.preferences = RunnerPreferences()
                return self.makePetMenu(surface: surface)
            }
        )
        floatingPetController = controller
        return controller
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
