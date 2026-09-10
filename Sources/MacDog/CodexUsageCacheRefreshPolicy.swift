import Foundation

enum CodexUsageCacheRefreshPolicy {
    static let cacheReadInterval: TimeInterval = 60
    static let cacheReadTolerance: TimeInterval = 6
    static let requestTimeout: TimeInterval = 15
    static let processTimeout: TimeInterval = 17
    static let minimumRetryInterval: TimeInterval = 60

    static func shouldRunLiveRefresh(for mode: UsageProviderMode) -> Bool {
        mode == .codex
    }

    static func shouldRunLiveRefresh(for selection: UsageProviderSelection) -> Bool {
        selection.includesCodex
    }

    static func shouldRunLiveRefresh(
        for mode: UsageProviderMode,
        selection: UsageProviderSelection
    ) -> Bool {
        mode != .claude && shouldRunLiveRefresh(for: selection)
    }
}

enum GrokUsageCacheRefreshPolicy {
    static let requestTimeout: TimeInterval = CodexUsageCacheRefreshPolicy.requestTimeout
    static let processTimeout: TimeInterval = 40

    static func shouldRunLiveRefresh(for mode: UsageProviderMode) -> Bool {
        mode == .grok
    }

    static func shouldRunLiveRefresh(for selection: UsageProviderSelection) -> Bool {
        selection.includesGrok
    }

    static func shouldRunLiveRefresh(
        for mode: UsageProviderMode,
        selection: UsageProviderSelection
    ) -> Bool {
        mode != .claude && shouldRunLiveRefresh(for: selection)
    }
}
