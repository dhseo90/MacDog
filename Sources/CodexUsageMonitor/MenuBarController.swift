import AppKit
import CodexUsageCore
import SwiftUI

@MainActor
final class MenuBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private let cacheStore = CodexUsageCacheStore()
    private var preferences = RunnerPreferences()
    private var animationTimer: Timer?
    private var refreshTimer: Timer?
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
        guard let button = statusItem.button else { return }
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(togglePopover)
        button.toolTip = "Codex Usage"
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
        statusItem.button?.image = runnerImage(frame: frameIndex)
    }

    private func runnerImage(frame: Int) -> NSImage? {
        let symbolName: String
        if state.phase == .limit {
            symbolName = "exclamationmark.triangle.fill"
        } else if state.reducedMotion {
            symbolName = filledSymbolName
        } else {
            symbolName = frame % 2 == 0 ? filledSymbolName : outlineSymbolName
        }

        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        guard let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Codex Usage")?
            .withSymbolConfiguration(configuration) else {
            return RunnerIconRenderer().image(
                frame: frame,
                phase: state.phase,
                theme: preferences.theme,
                reducedMotion: state.reducedMotion
            )
        }
        image.isTemplate = true
        return image
    }

    private var outlineSymbolName: String {
        switch preferences.theme {
        case .pup:
            "dog"
        case .spark:
            "pawprint"
        case .pulse:
            "dog.circle"
        }
    }

    private var filledSymbolName: String {
        switch preferences.theme {
        case .pup:
            "dog.fill"
        case .spark:
            "pawprint.fill"
        case .pulse:
            "dog.circle.fill"
        }
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
        refreshUsage(allowLiveRefresh: true)

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
