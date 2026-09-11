import Foundation

struct UsageProviderWorkDiff: Equatable, Sendable {
    var cancelNotifications: Bool
    var cancelCodexRefresh: Bool
    var cancelGrokRefresh: Bool
    var synchronizeCacheAgents: Bool

    static let none = UsageProviderWorkDiff(
        cancelNotifications: false,
        cancelCodexRefresh: false,
        cancelGrokRefresh: false,
        synchronizeCacheAgents: false
    )

    static func make(
        from previous: RunnerPreferences,
        to current: RunnerPreferences
    ) -> UsageProviderWorkDiff {
        make(
            previousMode: previous.usageProviderMode,
            previousSelection: previous.usageProviderSelection,
            currentMode: current.usageProviderMode,
            currentSelection: current.usageProviderSelection
        )
    }

    static func make(
        previousMode: UsageProviderMode,
        previousSelection: UsageProviderSelection,
        currentMode: UsageProviderMode,
        currentSelection: UsageProviderSelection
    ) -> UsageProviderWorkDiff {
        let claudeInvolved = previousMode == .claude || currentMode == .claude
        let modeChanged = previousMode != currentMode

        if claudeInvolved {
            guard modeChanged else { return .none }
            return UsageProviderWorkDiff(
                cancelNotifications: true,
                cancelCodexRefresh: true,
                cancelGrokRefresh: true,
                synchronizeCacheAgents: true
            )
        }

        let previousRuntime = previousSelection.main
        let currentRuntime = currentSelection.main
        let enabledChanged = previousSelection.enabled != currentSelection.enabled
        return UsageProviderWorkDiff(
            cancelNotifications: previousRuntime != currentRuntime || modeChanged,
            cancelCodexRefresh: previousSelection.includesCodex && !currentSelection.includesCodex,
            cancelGrokRefresh: previousSelection.includesGrok && !currentSelection.includesGrok,
            synchronizeCacheAgents: enabledChanged
        )
    }
}
