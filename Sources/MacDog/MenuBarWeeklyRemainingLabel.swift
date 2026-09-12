import CodexUsageCore
import Foundation

struct MenuBarWeeklyRemainingLabel: Equatable {
    let text: String?

    static func make(state: UsageMonitorState, now: Date = Date()) -> MenuBarWeeklyRemainingLabel {
        guard state.usageProviderMode != .claude else {
            return MenuBarWeeklyRemainingLabel(text: nil)
        }

        let remainingPercent: Double?
        switch state.runtimeProviderMode {
        case .codex:
            remainingPercent = state.codexLimit?.weekly?.remainingPercent
        case .grok:
            remainingPercent = state.grokUsage.cacheSnapshot?.freshWeekly(now: now)?.remainingPercent
        case .claude:
            remainingPercent = nil
        }

        guard let remainingPercent else {
            return MenuBarWeeklyRemainingLabel(text: nil)
        }

        let percent = Int(remainingPercent.rounded(.toNearestOrAwayFromZero))
        return MenuBarWeeklyRemainingLabel(text: "\(percent)%")
    }
}
