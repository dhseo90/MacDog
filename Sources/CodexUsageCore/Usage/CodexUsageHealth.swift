import Foundation

public enum CodexUsageHealthState: String, Equatable, Sendable {
    case ok
    case missing
    case stale
    case error
    case waiting
}

public enum CodexUsageHealthAppendState: String, Equatable, Sendable {
    case stored
    case skipped
    case missing
    case unavailable
}

public enum CodexUsageHealthPaceState: String, Equatable, Sendable {
    case projected
    case waitingForSamples
    case stale
    case error
    case unavailable
}

public struct CodexUsageHealthReport: Equatable, Sendable {
    public let cacheFileURL: URL
    public let cacheState: CodexUsageHealthState
    public let cacheAgeSeconds: Int?
    public let cacheStaleAfterSeconds: Int?
    public let cacheHasReport: Bool
    public let weeklyHistoryFileURL: URL
    public let weeklyHistoryState: CodexUsageHealthState
    public let weeklySampleCount: Int
    public let latestWeeklySampleResetsAt: Int?
    public let weeklyAppendState: CodexUsageHealthAppendState
    public let resetWindowHistoryFileURL: URL
    public let resetWindowHistoryState: CodexUsageHealthState
    public let resetWindowRecordCount: Int
    public let latestResetWindowResetsAt: Int?
    public let resetWindowAppendState: CodexUsageHealthAppendState
    public let resetWindowRetentionState: CodexUsageHealthState
    public let resetWindowRetentionLimit: Int
    public let paceState: CodexUsageHealthPaceState
    public let paceSampleCount: Int

    public init(
        cacheFileURL: URL,
        cacheState: CodexUsageHealthState,
        cacheAgeSeconds: Int?,
        cacheStaleAfterSeconds: Int?,
        cacheHasReport: Bool,
        weeklyHistoryFileURL: URL,
        weeklyHistoryState: CodexUsageHealthState,
        weeklySampleCount: Int,
        latestWeeklySampleResetsAt: Int?,
        weeklyAppendState: CodexUsageHealthAppendState = .unavailable,
        resetWindowHistoryFileURL: URL,
        resetWindowHistoryState: CodexUsageHealthState,
        resetWindowRecordCount: Int,
        latestResetWindowResetsAt: Int?,
        resetWindowAppendState: CodexUsageHealthAppendState = .unavailable,
        resetWindowRetentionState: CodexUsageHealthState = .waiting,
        resetWindowRetentionLimit: Int = CodexUsageResetWindowHistoryStore.completedWindowRetentionCount + 1,
        paceState: CodexUsageHealthPaceState = .unavailable,
        paceSampleCount: Int = 0
    ) {
        self.cacheFileURL = cacheFileURL
        self.cacheState = cacheState
        self.cacheAgeSeconds = cacheAgeSeconds
        self.cacheStaleAfterSeconds = cacheStaleAfterSeconds
        self.cacheHasReport = cacheHasReport
        self.weeklyHistoryFileURL = weeklyHistoryFileURL
        self.weeklyHistoryState = weeklyHistoryState
        self.weeklySampleCount = weeklySampleCount
        self.latestWeeklySampleResetsAt = latestWeeklySampleResetsAt
        self.weeklyAppendState = weeklyAppendState
        self.resetWindowHistoryFileURL = resetWindowHistoryFileURL
        self.resetWindowHistoryState = resetWindowHistoryState
        self.resetWindowRecordCount = resetWindowRecordCount
        self.latestResetWindowResetsAt = latestResetWindowResetsAt
        self.resetWindowAppendState = resetWindowAppendState
        self.resetWindowRetentionState = resetWindowRetentionState
        self.resetWindowRetentionLimit = resetWindowRetentionLimit
        self.paceState = paceState
        self.paceSampleCount = max(0, paceSampleCount)
    }
}

public struct CodexUsageHealthReader {
    private let cacheFileURL: URL
    private let now: Date
    private let fileManager: FileManager

    public init(
        cacheFileURL: URL = CodexUsageCacheStore.defaultFileURL(),
        now: Date = Date(),
        fileManager: FileManager = .default
    ) {
        self.cacheFileURL = cacheFileURL
        self.now = now
        self.fileManager = fileManager
    }

    public func read() -> CodexUsageHealthReport {
        let weeklyHistoryFileURL = CodexUsageWeeklyHistoryStore.defaultFileURL(
            adjacentToCacheFileURL: cacheFileURL
        )
        let resetWindowHistoryFileURL = CodexUsageResetWindowHistoryStore.defaultFileURL(
            adjacentToCacheFileURL: cacheFileURL
        )
        let cacheHealth = readCacheHealth()
        let weeklyHealth = readWeeklyHistoryHealth(fileURL: weeklyHistoryFileURL)
        let resetWindowHealth = readResetWindowHistoryHealth(fileURL: resetWindowHistoryFileURL)
        let currentSample = cacheHealth.snapshot.flatMap {
            currentWeeklySample(from: $0)
        }
        let appendHealth = readAppendHealth(
            currentSample: currentSample,
            weeklyHistory: weeklyHealth.weeklyHistory,
            resetWindowHistory: resetWindowHealth.resetWindowHistory
        )
        let paceHealth = readPaceHealth(
            snapshot: cacheHealth.snapshot,
            weeklyHistory: weeklyHealth.weeklyHistory
        )

        return CodexUsageHealthReport(
            cacheFileURL: cacheFileURL,
            cacheState: cacheHealth.state,
            cacheAgeSeconds: cacheHealth.ageSeconds,
            cacheStaleAfterSeconds: cacheHealth.staleAfterSeconds,
            cacheHasReport: cacheHealth.hasReport,
            weeklyHistoryFileURL: weeklyHistoryFileURL,
            weeklyHistoryState: weeklyHealth.state,
            weeklySampleCount: weeklyHealth.sampleCount,
            latestWeeklySampleResetsAt: weeklyHealth.latestResetsAt,
            weeklyAppendState: appendHealth.weekly,
            resetWindowHistoryFileURL: resetWindowHistoryFileURL,
            resetWindowHistoryState: resetWindowHealth.state,
            resetWindowRecordCount: resetWindowHealth.recordCount,
            latestResetWindowResetsAt: resetWindowHealth.latestResetsAt,
            resetWindowAppendState: appendHealth.resetWindow,
            resetWindowRetentionState: resetWindowHealth.retentionState,
            resetWindowRetentionLimit: resetWindowHealth.retentionLimit,
            paceState: paceHealth.state,
            paceSampleCount: paceHealth.sampleCount
        )
    }

    private func readCacheHealth() -> CacheHealth {
        guard fileManager.fileExists(atPath: cacheFileURL.path) else {
            return CacheHealth(
                state: .missing,
                ageSeconds: nil,
                staleAfterSeconds: nil,
                hasReport: false,
                snapshot: nil
            )
        }

        do {
            let snapshot = try CodexUsageCacheStore(fileURL: cacheFileURL, fileManager: fileManager).read()
            let state: CodexUsageHealthState
            if snapshot.error != nil {
                state = .error
            } else if snapshot.isStale(now: now) {
                state = .stale
            } else if snapshot.report != nil {
                state = .ok
            } else {
                state = .waiting
            }
            return CacheHealth(
                state: state,
                ageSeconds: max(Int(now.timeIntervalSince1970) - snapshot.cachedAt, 0),
                staleAfterSeconds: snapshot.staleAfterSeconds,
                hasReport: snapshot.report != nil,
                snapshot: snapshot
            )
        } catch {
            return CacheHealth(
                state: .error,
                ageSeconds: nil,
                staleAfterSeconds: nil,
                hasReport: false,
                snapshot: nil
            )
        }
    }

    private func readWeeklyHistoryHealth(fileURL: URL) -> HistoryHealth {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return HistoryHealth(
                state: .missing,
                sampleCount: 0,
                recordCount: 0,
                latestResetsAt: nil,
                weeklyHistory: nil,
                resetWindowHistory: nil,
                retentionState: .waiting,
                retentionLimit: Self.resetWindowRetentionLimit
            )
        }

        do {
            let history = try CodexUsageWeeklyHistoryStore(fileURL: fileURL, fileManager: fileManager).read()
            let latestSample = history.samples.max {
                if $0.recordedAt != $1.recordedAt {
                    return $0.recordedAt < $1.recordedAt
                }
                return $0.resetsAt < $1.resetsAt
            }
            return HistoryHealth(
                state: history.samples.isEmpty ? .waiting : .ok,
                sampleCount: history.samples.count,
                recordCount: 0,
                latestResetsAt: latestSample?.resetsAt,
                weeklyHistory: history,
                resetWindowHistory: nil,
                retentionState: .waiting,
                retentionLimit: Self.resetWindowRetentionLimit
            )
        } catch {
            return HistoryHealth(
                state: .error,
                sampleCount: 0,
                recordCount: 0,
                latestResetsAt: nil,
                weeklyHistory: nil,
                resetWindowHistory: nil,
                retentionState: .waiting,
                retentionLimit: Self.resetWindowRetentionLimit
            )
        }
    }

    private func readResetWindowHistoryHealth(fileURL: URL) -> HistoryHealth {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return HistoryHealth(
                state: .missing,
                sampleCount: 0,
                recordCount: 0,
                latestResetsAt: nil,
                weeklyHistory: nil,
                resetWindowHistory: nil,
                retentionState: .waiting,
                retentionLimit: Self.resetWindowRetentionLimit
            )
        }

        do {
            let history = try CodexUsageResetWindowHistoryStore(fileURL: fileURL, fileManager: fileManager).read()
            let latestRecord = history.records.max {
                if $0.resetsAt != $1.resetsAt {
                    return $0.resetsAt < $1.resetsAt
                }
                return $0.generatedAt < $1.generatedAt
            }
            return HistoryHealth(
                state: history.records.isEmpty ? .waiting : .ok,
                sampleCount: 0,
                recordCount: history.records.count,
                latestResetsAt: latestRecord?.resetsAt,
                weeklyHistory: nil,
                resetWindowHistory: history,
                retentionState: retentionState(for: history),
                retentionLimit: Self.resetWindowRetentionLimit
            )
        } catch {
            return HistoryHealth(
                state: .error,
                sampleCount: 0,
                recordCount: 0,
                latestResetsAt: nil,
                weeklyHistory: nil,
                resetWindowHistory: nil,
                retentionState: .error,
                retentionLimit: Self.resetWindowRetentionLimit
            )
        }
    }

    private func readAppendHealth(
        currentSample: CodexUsageWeeklyHistorySample?,
        weeklyHistory: CodexUsageWeeklyHistory?,
        resetWindowHistory: CodexUsageResetWindowHistory?
    ) -> AppendHealth {
        guard let currentSample else {
            return AppendHealth(weekly: .unavailable, resetWindow: .unavailable)
        }

        return AppendHealth(
            weekly: weeklyAppendState(currentSample: currentSample, history: weeklyHistory),
            resetWindow: resetWindowAppendState(currentSample: currentSample, history: resetWindowHistory)
        )
    }

    private func weeklyAppendState(
        currentSample: CodexUsageWeeklyHistorySample,
        history: CodexUsageWeeklyHistory?
    ) -> CodexUsageHealthAppendState {
        guard let history else { return .missing }
        if history.samples.contains(where: { isStoredWeeklySample($0, currentSample) }) {
            return .stored
        }

        let previousSample = history.samples
            .filter {
                $0.recordedAt <= currentSample.recordedAt &&
                    $0.matchesResetWindow(
                        resetsAt: currentSample.resetsAt,
                        windowDurationMins: currentSample.windowDurationMins
                    )
            }
            .max { $0.recordedAt < $1.recordedAt }
        guard let previousSample else { return .missing }

        let timeDelta = currentSample.recordedAt - previousSample.recordedAt
        let remainingDelta = abs(currentSample.remainingPercent - previousSample.remainingPercent)
        if timeDelta >= 0,
           timeDelta < CodexUsageWeeklyHistoryStore.minimumSampleIntervalSeconds,
           remainingDelta < CodexUsageWeeklyHistoryStore.minimumRemainingPercentDelta {
            return .skipped
        }
        return .missing
    }

    private func resetWindowAppendState(
        currentSample: CodexUsageWeeklyHistorySample,
        history: CodexUsageResetWindowHistory?
    ) -> CodexUsageHealthAppendState {
        guard let history else { return .missing }
        return history.records.contains {
            isSameLogicalResetWindow(record: $0, sample: currentSample)
        } ? .stored : .missing
    }

    private func readPaceHealth(
        snapshot: CodexUsageCacheSnapshot?,
        weeklyHistory: CodexUsageWeeklyHistory?
    ) -> PaceHealth {
        guard let snapshot else {
            return PaceHealth(state: .unavailable, sampleCount: 0)
        }

        let projection = CodexUsagePaceProjectionBuilder().projection(
            snapshot: snapshot,
            weeklyHistory: weeklyHistory ?? .empty,
            now: now
        )
        return PaceHealth(
            state: CodexUsageHealthPaceState(projection.state),
            sampleCount: projection.sampleCount
        )
    }

    private func retentionState(for history: CodexUsageResetWindowHistory) -> CodexUsageHealthState {
        guard !history.records.isEmpty else { return .waiting }
        let exceedsLimit = Dictionary(grouping: history.records) {
            RetentionGroupKey(limitId: $0.limitId, windowDurationMins: $0.windowDurationMins)
        }
        .values
        .contains { $0.count > Self.resetWindowRetentionLimit }
        return exceedsLimit ? .error : .ok
    }

    private func currentWeeklySample(from snapshot: CodexUsageCacheSnapshot) -> CodexUsageWeeklyHistorySample? {
        guard let report = snapshot.report else { return nil }
        return CodexUsageWeeklyHistorySample(report: report, recordedAt: snapshot.cachedAt)
    }

    private func isStoredWeeklySample(
        _ stored: CodexUsageWeeklyHistorySample,
        _ current: CodexUsageWeeklyHistorySample
    ) -> Bool {
        stored.recordedAt == current.recordedAt &&
            stored.matchesResetWindow(
                resetsAt: current.resetsAt,
                windowDurationMins: current.windowDurationMins
            )
    }

    private func isSameLogicalResetWindow(
        record: CodexUsageResetWindowHistoryRecord,
        sample: CodexUsageWeeklyHistorySample
    ) -> Bool {
        guard record.limitId == "codex",
              record.windowDurationMins == sample.windowDurationMins
        else {
            return false
        }

        let sampleResetStartAt = sample.resetsAt - sample.windowDurationMins * 60
        let tolerance = CodexUsageResetWindowHistoryStore.logicalResetWindowToleranceSeconds(
            windowDurationMins: sample.windowDurationMins
        )
        return abs(record.resetStartAt - sampleResetStartAt) <= tolerance
    }

    private struct CacheHealth {
        let state: CodexUsageHealthState
        let ageSeconds: Int?
        let staleAfterSeconds: Int?
        let hasReport: Bool
        let snapshot: CodexUsageCacheSnapshot?
    }

    private struct HistoryHealth {
        let state: CodexUsageHealthState
        let sampleCount: Int
        let recordCount: Int
        let latestResetsAt: Int?
        let weeklyHistory: CodexUsageWeeklyHistory?
        let resetWindowHistory: CodexUsageResetWindowHistory?
        let retentionState: CodexUsageHealthState
        let retentionLimit: Int
    }

    private struct AppendHealth {
        let weekly: CodexUsageHealthAppendState
        let resetWindow: CodexUsageHealthAppendState
    }

    private struct PaceHealth {
        let state: CodexUsageHealthPaceState
        let sampleCount: Int
    }

    private struct RetentionGroupKey: Hashable {
        let limitId: String
        let windowDurationMins: Int
    }
}

private extension CodexUsageHealthReader {
    static var resetWindowRetentionLimit: Int {
        CodexUsageResetWindowHistoryStore.completedWindowRetentionCount + 1
    }
}

private extension CodexUsageHealthPaceState {
    init(_ state: CodexUsagePaceProjectionState) {
        switch state {
        case .projected:
            self = .projected
        case .waitingForSamples:
            self = .waitingForSamples
        case .stale:
            self = .stale
        case .error:
            self = .error
        case .unavailable:
            self = .unavailable
        }
    }
}
