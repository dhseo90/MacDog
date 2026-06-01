import Foundation

enum CodexUsageCacheRefreshPolicy {
    static let cacheReadInterval: TimeInterval = 60
    static let cacheReadTolerance: TimeInterval = 6
    static let requestTimeout: TimeInterval = 5
    static let processTimeout: TimeInterval = 7
    static let minimumRetryInterval: TimeInterval = 60
}
