import AppKit
import CodexUsageCore
import MacDogPrivilegedHelperSupport
import SwiftUI

@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: 38)
    private let popover = NSPopover()
    private let runnerRenderer = RunnerIconRenderer()
    private let cacheStore = CodexUsageCacheStore(fileURL: CodexUsageCacheStore.defaultSharedFileURL())
    private let privilegedHelperInstallStateReader = PrivilegedHelperInstallStateReader(
        fileChecker: FileManagerPrivilegedHelperFileChecker()
    )
    private let privilegedHelperInstaller = PrivilegedHelperInstaller()
    private let sleepPreventionController = SleepPreventionController()
    private var sleepPreventionTriggerStatus = SleepPreventionTriggerStatus.disabled
    private var preferences = RunnerPreferences()
    private var animationTimer: Timer?
    private var refreshTimer: Timer?
    private var popoverMetricsTimer: Timer?
    private var liveRefreshTask: Task<Void, Never>?
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private var floatingPetController: FloatingPetController?
    private var frameIndex = 0
    private var state = UsageMonitorState.empty
    private var systemMetricsHistory = SystemMetricsHistory.empty

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
        popover.contentSize = NSSize(width: 370, height: 408)
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

    private func startPopoverMetricsTimer() {
        popoverMetricsTimer?.invalidate()
        popoverMetricsTimer = Timer.scheduledTimer(withTimeInterval: PopoverMetricsRefreshPolicy.localMetricsInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPopoverMetricsIfNeeded()
            }
        }
        popoverMetricsTimer?.tolerance = PopoverMetricsRefreshPolicy.localMetricsTolerance
    }

    private func stopPopoverMetricsTimer() {
        popoverMetricsTimer?.invalidate()
        popoverMetricsTimer = nil
    }

    private func refreshPopoverMetricsIfNeeded() {
        guard popover.isShown, shouldRefreshLocalMetricsForSelectedPopoverModule else { return }

        preferences = RunnerPreferences()

        if MacDogDemoData.isEnabled {
            applyState(MacDogDemoData.state(preferences: preferences))
            return
        }

        let systemMetrics = captureSystemMetrics()
        syncSleepPrevention(systemMetrics: systemMetrics)
        applyState(state.withSystemMetrics(
            systemMetrics,
            systemMetricsHistory: systemMetricsHistory,
            sleepPreventionStatus: sleepPreventionController.status,
            sleepPreventionTriggerStatus: sleepPreventionTriggerStatus,
            privilegedHelperInstallSnapshot: privilegedHelperInstallSnapshot()
        ))
    }

    private var shouldRefreshLocalMetricsForSelectedPopoverModule: Bool {
        let rawValue = UserDefaults.standard.string(forKey: RunnerPreferences.popoverModuleKey) ?? MacDogPopoverModule.codex.rawValue
        return PopoverMetricsRefreshPolicy.shouldRefreshLocalMetrics(forRawValue: rawValue)
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
        RunnerPreferences.expireSleepPreventionIfNeeded()
        preferences = RunnerPreferences()

        if MacDogDemoData.isEnabled {
            applyState(MacDogDemoData.state(preferences: preferences))
            if previousPhase != state.phase || previousPreferences != preferences {
                restartAnimationTimer()
            }
            syncDesktopPetVisibility()
            return
        }

        let systemMetrics = captureSystemMetrics()
        syncSleepPrevention(systemMetrics: systemMetrics)
        applyState(loadCachedState(systemMetrics: systemMetrics))

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
        updatePopoverController()
        statusItem.button?.toolTip = state.toolTip
        renderCurrentFrame()
    }

    private func loadCachedState(errorMessage: String? = nil, systemMetrics: SystemMetricsSnapshot = .capture()) -> UsageMonitorState {
        if let snapshot = try? cacheStore.read(), let report = snapshot.report {
            return UsageMonitorState(
                report: report,
                cacheSnapshot: snapshot,
                errorMessage: errorMessage ?? snapshot.error?.message,
                displayBasis: preferences.displayBasis,
                reducedMotion: preferences.reducedMotion,
                animationPaused: preferences.animationPaused,
                systemMetrics: systemMetrics,
                systemMetricsHistory: systemMetricsHistory,
                sleepPreventionStatus: sleepPreventionController.status,
                sleepPreventionTriggerStatus: sleepPreventionTriggerStatus,
                privilegedHelperInstallSnapshot: privilegedHelperInstallSnapshot()
            )
        }

        return UsageMonitorState(
            report: nil,
            cacheSnapshot: nil,
            errorMessage: "사용량 캐시가 아직 없습니다.",
            displayBasis: preferences.displayBasis,
            reducedMotion: preferences.reducedMotion,
            animationPaused: preferences.animationPaused,
            systemMetrics: systemMetrics,
            systemMetricsHistory: systemMetricsHistory,
            sleepPreventionStatus: sleepPreventionController.status,
            sleepPreventionTriggerStatus: sleepPreventionTriggerStatus,
            privilegedHelperInstallSnapshot: privilegedHelperInstallSnapshot()
        )
    }

    private func requestLiveRefresh() {
        guard !MacDogDemoData.isEnabled else {
            applyState(MacDogDemoData.state(preferences: preferences))
            return
        }

        liveRefreshTask?.cancel()
        applyState(state.withRefreshing(true))
        liveRefreshTask = Task { [weak self] in
            let result = await Self.fetchLiveUsage()
            guard !Task.isCancelled, let self else { return }
            let previousPhase = self.state.phase
            let previousPreferences = self.preferences
            self.preferences = RunnerPreferences()
            let systemMetrics = self.captureSystemMetrics()
            self.syncSleepPrevention(systemMetrics: systemMetrics)
            self.applyState(self.state(from: result, systemMetrics: systemMetrics))
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
            applyState(loadCachedState(systemMetrics: captureSystemMetrics()))
        }
    }

    nonisolated private static func fetchLiveUsage() async -> LiveUsageRefreshResult {
        await Task.detached(priority: .userInitiated) {
            let cacheStores = CodexUsageCacheStore.defaultMirroredFileURLs().map {
                CodexUsageCacheStore(fileURL: $0)
            }
            let primaryCacheStore = CodexUsageCacheStore(fileURL: CodexUsageCacheStore.defaultSharedFileURL())

            do {
                let report = try CodexUsageService(client: CodexAppServerClient()).readReport()
                cacheStores.forEach { try? $0.writeSuccess(report: report) }
                return .success(report)
            } catch {
                return .failure(
                    message: error.localizedDescription,
                    cachedSnapshot: try? primaryCacheStore.read()
                )
            }
        }.value
    }

    private func state(from result: LiveUsageRefreshResult, systemMetrics: SystemMetricsSnapshot = .capture()) -> UsageMonitorState {
        switch result {
        case .success(let report):
            UsageMonitorState(
                report: report,
                cacheSnapshot: nil,
                errorMessage: nil,
                displayBasis: preferences.displayBasis,
                reducedMotion: preferences.reducedMotion,
                animationPaused: preferences.animationPaused,
                systemMetrics: systemMetrics,
                systemMetricsHistory: systemMetricsHistory,
                sleepPreventionStatus: sleepPreventionController.status,
                sleepPreventionTriggerStatus: sleepPreventionTriggerStatus,
                privilegedHelperInstallSnapshot: privilegedHelperInstallSnapshot()
            )
        case .failure(let message, let snapshot):
            if let snapshot, let report = snapshot.report {
                UsageMonitorState(
                    report: report,
                    cacheSnapshot: snapshot,
                    errorMessage: message,
                    displayBasis: preferences.displayBasis,
                    reducedMotion: preferences.reducedMotion,
                    animationPaused: preferences.animationPaused,
                    systemMetrics: systemMetrics,
                    systemMetricsHistory: systemMetricsHistory,
                    sleepPreventionStatus: sleepPreventionController.status,
                    sleepPreventionTriggerStatus: sleepPreventionTriggerStatus,
                    privilegedHelperInstallSnapshot: privilegedHelperInstallSnapshot()
                )
            } else {
                UsageMonitorState(
                    report: nil,
                    cacheSnapshot: nil,
                    errorMessage: message,
                    displayBasis: preferences.displayBasis,
                    reducedMotion: preferences.reducedMotion,
                    animationPaused: preferences.animationPaused,
                    systemMetrics: systemMetrics,
                    systemMetricsHistory: systemMetricsHistory,
                    sleepPreventionStatus: sleepPreventionController.status,
                    sleepPreventionTriggerStatus: sleepPreventionTriggerStatus,
                    privilegedHelperInstallSnapshot: privilegedHelperInstallSnapshot()
                )
            }
        }
    }

    private func privilegedHelperInstallSnapshot() -> PrivilegedHelperInstallSnapshot {
        privilegedHelperInstallStateReader.snapshot()
    }

    private func captureSystemMetrics() -> SystemMetricsSnapshot {
        let snapshot = SystemMetricsSnapshot.capture()
        systemMetricsHistory = systemMetricsHistory.appending(snapshot)
        return snapshot
    }

    private func makePopoverController() -> NSViewController {
        NSHostingController(rootView: makePopoverView())
    }

    private func updatePopoverController() {
        if let hostingController = popover.contentViewController as? NSHostingController<UsagePopoverView> {
            hostingController.rootView = makePopoverView()
        } else {
            popover.contentViewController = makePopoverController()
        }
    }

    private func makePopoverView() -> UsagePopoverView {
        UsagePopoverView(
            state: state,
            onPreferencesChanged: {
                Task { @MainActor in
                    self.refreshUsage(allowLiveRefresh: false)
                }
            },
            onAction: { action in
                Task { @MainActor in
                    self.perform(action)
                }
            }
        )
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
        case .setSleepPreventionMode(let mode):
            RunnerPreferences.setSleepPreventionMode(mode)
            refreshUsage(allowLiveRefresh: false)
        case .setSleepPreventionEnabled(let isEnabled):
            RunnerPreferences.setSleepPreventionEnabled(isEnabled)
            refreshUsage(allowLiveRefresh: false)
        case .setSleepPreventionSessionPreset(let preset):
            RunnerPreferences.setSleepPreventionSessionPreset(preset)
            refreshUsage(allowLiveRefresh: false)
        case .setSleepPreventionPowerAdapterTrigger(let isEnabled):
            RunnerPreferences.setSleepPreventionPowerAdapterTrigger(isEnabled)
            refreshUsage(allowLiveRefresh: false)
        case .setSleepPreventionCodexAppTrigger(let isEnabled):
            RunnerPreferences.setSleepPreventionCodexAppTrigger(isEnabled)
            refreshUsage(allowLiveRefresh: false)
        case .setSleepPreventionChargingBelowThresholdTrigger(let isEnabled):
            RunnerPreferences.setSleepPreventionChargingBelowThresholdTrigger(isEnabled)
            refreshUsage(allowLiveRefresh: false)
        case .setSleepPreventionCPUThresholdTrigger(let isEnabled):
            RunnerPreferences.setSleepPreventionCPUThresholdTrigger(isEnabled)
            refreshUsage(allowLiveRefresh: false)
        case .setSleepPreventionNetworkActivityTrigger(let isEnabled):
            RunnerPreferences.setSleepPreventionNetworkActivityTrigger(isEnabled)
            refreshUsage(allowLiveRefresh: false)
        case .setSleepPreventionExternalVolumeTrigger(let isEnabled):
            RunnerPreferences.setSleepPreventionExternalVolumeTrigger(isEnabled)
            refreshUsage(allowLiveRefresh: false)
        case .setSleepPreventionPreventDisplaySleep(let isEnabled):
            RunnerPreferences.setSleepPreventionPreventDisplaySleep(isEnabled)
            refreshUsage(allowLiveRefresh: false)
        case .setSleepPreventionPreventClosedLidSleep(let isEnabled):
            RunnerPreferences.setSleepPreventionPreventClosedLidSleep(isEnabled)
            refreshUsage(allowLiveRefresh: false)
        case .setSleepPreventionDisableScreenLock(let isEnabled):
            RunnerPreferences.setSleepPreventionDisableScreenLock(isEnabled)
            refreshUsage(allowLiveRefresh: false)
        case .installPrivilegedHelper:
            runPrivilegedHelperOperation(.install)
        case .uninstallPrivilegedHelper:
            runPrivilegedHelperOperation(.uninstall)
        case .openBatterySettings:
            _ = SystemSettingsDestination.openBatterySettings()
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

    private enum PrivilegedHelperOperation: Sendable {
        case install
        case uninstall

        var successTitle: String {
            switch self {
            case .install:
                "권한 도우미 설치 완료"
            case .uninstall:
                "권한 도우미 제거 완료"
            }
        }

        var successMessage: String {
            switch self {
            case .install:
                "덮개 닫힘 보호 설정 변경은 권한 도우미 XPC 경로를 우선 사용합니다."
            case .uninstall:
                "덮개 닫힘 보호 설정 변경 시 다시 관리자 승인이 필요할 수 있습니다."
            }
        }
    }

    private func runPrivilegedHelperOperation(_ operation: PrivilegedHelperOperation) {
        Task { [weak self] in
            guard let self else { return }
            let installer = privilegedHelperInstaller
            do {
                try await Task.detached(priority: .userInitiated) {
                    switch operation {
                    case .install:
                        try installer.install()
                    case .uninstall:
                        try installer.uninstall()
                    }
                }.value

                refreshUsage(allowLiveRefresh: false)
                showPrivilegedHelperAlert(
                    title: operation.successTitle,
                    message: operation.successMessage,
                    style: .informational
                )
            } catch {
                refreshUsage(allowLiveRefresh: false)
                showPrivilegedHelperAlert(
                    title: "권한 도우미 작업 실패",
                    message: error.localizedDescription,
                    style: .warning
                )
            }
        }
    }

    private func showPrivilegedHelperAlert(title: String, message: String, style: NSAlert.Style) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: "확인")
        alert.runModal()
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
        let model = PetMenuModel(preferences: preferences, surface: surface)
        let menu = NSMenu(title: model.title)
        for entry in model.entries {
            switch entry {
            case .command(let command):
                menu.addItem(menuItem(for: command))
            case .submenu(let submenu):
                menu.addItem(submenuItem(for: submenu))
            case .separator:
                menu.addItem(.separator())
            }
        }
        return menu
    }

    private func submenuItem(for submenuModel: PetMenuSubmenu) -> NSMenuItem {
        let parent = NSMenuItem(title: submenuModel.title, action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: submenuModel.title)
        for command in submenuModel.commands {
            submenu.addItem(menuItem(for: command))
        }
        parent.submenu = submenu
        parent.isEnabled = submenuModel.isEnabled
        return parent
    }

    private func menuItem(for command: PetMenuCommand) -> NSMenuItem {
        let item = NSMenuItem(title: command.title, action: #selector(menuPerformAction(_:)), keyEquivalent: "")
        item.target = self
        item.state = command.isSelected ? .on : .off
        item.isEnabled = command.isEnabled
        item.representedObject = PetMenuActionBox(command.action)
        return item
    }

    @objc
    private func menuPerformAction(_ sender: NSMenuItem) {
        guard let box = sender.representedObject as? PetMenuActionBox else { return }
        perform(box.action)
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

    private func syncSleepPrevention(systemMetrics: SystemMetricsSnapshot) {
        sleepPreventionTriggerStatus = SleepPreventionTriggerStatus.capture(
            preferences: preferences,
            systemMetrics: systemMetrics
        )
        let isEnabled = preferences.sleepPreventionEnabled || sleepPreventionTriggerStatus.isMatched
        sleepPreventionController.setEnabled(
            isEnabled,
            endsAt: preferences.sleepPreventionEnabled ? preferences.sleepPreventionEndsAt : nil,
            policy: preferences.sleepPreventionPolicy
        )
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
            },
            usagePresenter: { [weak self] sourceView in
                Task { @MainActor in
                    self?.showUsagePopover(relativeTo: sourceView, placement: .desktopPet)
                }
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

        showUsagePopover(relativeTo: button, placement: .menuBar)
    }

    private func showUsagePopover(relativeTo sourceView: NSView, placement: UsagePopoverPlacement) {
        NSApp.activate(ignoringOtherApps: true)
        refreshUsage(allowLiveRefresh: false)
        if !popover.isShown {
            installOutsideClickMonitors()
            popover.show(
                relativeTo: popoverAnchorRect(in: sourceView, placement: placement),
                of: sourceView,
                preferredEdge: preferredEdge(for: sourceView, placement: placement)
            )
            startPopoverMetricsTimer()
        }
        positionPopoverWindow(relativeTo: sourceView, placement: placement)
        refreshPopoverMetricsIfNeeded()
        requestLiveRefresh()
    }

    nonisolated func popoverDidClose(_ notification: Notification) {
        Task { @MainActor in
            self.cancelLiveRefresh()
            self.stopPopoverMetricsTimer()
            self.removeOutsideClickMonitors()
        }
    }

    private func popoverAnchorRect(in sourceView: NSView, placement: UsagePopoverPlacement) -> NSRect {
        guard placement == .menuBar else {
            return sourceView.bounds
        }

        let width = min(sourceView.bounds.width, 24)
        return NSRect(
            x: (sourceView.bounds.width - width) / 2,
            y: sourceView.bounds.minY,
            width: width,
            height: sourceView.bounds.height
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

    private func preferredEdge(for sourceView: NSView, placement: UsagePopoverPlacement) -> NSRectEdge {
        guard placement == .desktopPet,
              let sourceWindow = sourceView.window
        else {
            return placement.defaultPreferredEdge
        }

        let sourceFrame = sourceWindow.convertToScreen(sourceView.convert(sourceView.bounds, to: nil))
        let screenFrame = (sourceWindow.screen ?? NSScreen.main)?.visibleFrame ?? sourceFrame
        return shouldShowDesktopPopoverOnRight(sourceFrame: sourceFrame, screenFrame: screenFrame) ? .maxX : .minX
    }

    private func positionPopoverWindow(relativeTo sourceView: NSView, placement: UsagePopoverPlacement) {
        guard
            let popoverWindow = popover.contentViewController?.view.window,
            let sourceWindow = sourceView.window,
            let screen = sourceWindow.screen ?? NSScreen.main
        else { return }

        let sourceFrame = sourceWindow.convertToScreen(sourceView.convert(sourceView.bounds, to: nil))
        let screenFrame = screen.visibleFrame
        var frame = popoverWindow.frame
        switch placement {
        case .menuBar:
            frame.origin.x = sourceFrame.midX - frame.width / 2
            frame.origin.y = max(screenFrame.minY + 8, sourceFrame.minY - frame.height - 4)
        case .desktopPet:
            let padding: CGFloat = 8
            let showOnRight = shouldShowDesktopPopoverOnRight(sourceFrame: sourceFrame, screenFrame: screenFrame)
            frame.origin.x = showOnRight
                ? sourceFrame.maxX + padding
                : sourceFrame.minX - frame.width - padding
            frame.origin.y = sourceFrame.midY - frame.height / 2
        }
        frame.origin.x = min(max(frame.origin.x, screenFrame.minX + 8), screenFrame.maxX - frame.width - 8)
        frame.origin.y = min(max(frame.origin.y, screenFrame.minY + 8), screenFrame.maxY - frame.height - 8)
        popoverWindow.setFrame(frame, display: true)
    }

    private func shouldShowDesktopPopoverOnRight(sourceFrame: NSRect, screenFrame: NSRect) -> Bool {
        sourceFrame.midX <= screenFrame.midX
    }
}

private final class PetMenuActionBox: NSObject {
    let action: PetAction

    init(_ action: PetAction) {
        self.action = action
    }
}

private enum UsagePopoverPlacement {
    case menuBar
    case desktopPet

    var defaultPreferredEdge: NSRectEdge {
        switch self {
        case .menuBar:
            return .maxY
        case .desktopPet:
            return .maxX
        }
    }
}

private enum LiveUsageRefreshResult: Sendable {
    case success(CodexUsageReport)
    case failure(message: String, cachedSnapshot: CodexUsageCacheSnapshot?)
}
