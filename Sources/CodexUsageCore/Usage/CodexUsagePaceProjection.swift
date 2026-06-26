import Foundation

public enum CodexUsagePaceProjectionState: Equatable, Sendable {
    case projected
    case waitingForSamples
    case stale
    case error(message: String)
    case unavailable
}

public struct CodexUsagePaceProjection: Equatable, Sendable {
    public let state: CodexUsagePaceProjectionState
    public let generatedAt: Int
    public let limitId: String?
    public let windowDurationMins: Int?
    public let resetsAt: Int?
    public let currentUsedPercent: Double?
    public let usedPercentPerHour: Double?
    public let projectedFinalUsedPercent: Double?
    public let remainingSeconds: Int?
    public let sampleCount: Int

    public init(
        state: CodexUsagePaceProjectionState,
        generatedAt: Int,
        limitId: String?,
        windowDurationMins: Int?,
        resetsAt: Int?,
        currentUsedPercent: Double?,
        usedPercentPerHour: Double?,
        projectedFinalUsedPercent: Double?,
        remainingSeconds: Int?,
        sampleCount: Int
    ) {
        self.state = state
        self.generatedAt = generatedAt
        self.limitId = limitId
        self.windowDurationMins = windowDurationMins
        self.resetsAt = resetsAt
        self.currentUsedPercent = currentUsedPercent.map(Self.clampedPercent)
        self.usedPercentPerHour = usedPercentPerHour.map { max(0, $0) }
        self.projectedFinalUsedPercent = projectedFinalUsedPercent.map(Self.clampedPercent)
        self.remainingSeconds = remainingSeconds.map { max(0, $0) }
        self.sampleCount = max(0, sampleCount)
    }

    private static func clampedPercent(_ value: Double) -> Double {
        min(max(value, 0), 100)
    }
}

public struct CodexUsagePaceProjectionBuilder: Sendable {
    public init() {}

    public func projection(
        snapshot: CodexUsageCacheSnapshot,
        weeklyHistory: CodexUsageWeeklyHistory,
        now: Date = Date()
    ) -> CodexUsagePaceProjection {
        let generatedAt = Int(now.timeIntervalSince1970)

        if let error = snapshot.error {
            return unavailableProjection(
                state: .error(message: error.message),
                generatedAt: generatedAt
            )
        }

        guard let report = snapshot.report,
              let currentSample = CodexUsageWeeklyHistorySample(
                report: report,
                recordedAt: snapshot.cachedAt
              )
        else {
            return unavailableProjection(state: .unavailable, generatedAt: generatedAt)
        }

        if snapshot.isStale(now: now) {
            return unavailableProjection(
                state: .stale,
                generatedAt: generatedAt
            )
        }

        let limitId = report.codexLimit?.limitId ?? "codex"
        let matchingSamples = weeklyHistory.samples
            .filter {
                $0.recordedAt < currentSample.recordedAt &&
                    $0.matchesResetWindow(
                        resetsAt: currentSample.resetsAt,
                        windowDurationMins: currentSample.windowDurationMins
                    )
            }
            .sorted { $0.recordedAt < $1.recordedAt }

        guard let previousSample = matchingSamples.last else {
            return CodexUsagePaceProjection(
                state: .waitingForSamples,
                generatedAt: generatedAt,
                limitId: limitId,
                windowDurationMins: currentSample.windowDurationMins,
                resetsAt: currentSample.resetsAt,
                currentUsedPercent: currentSample.usedPercent,
                usedPercentPerHour: nil,
                projectedFinalUsedPercent: nil,
                remainingSeconds: max(0, currentSample.resetsAt - currentSample.recordedAt),
                sampleCount: 1
            )
        }

        let deltaSeconds = currentSample.recordedAt - previousSample.recordedAt
        guard deltaSeconds > 0 else {
            return CodexUsagePaceProjection(
                state: .waitingForSamples,
                generatedAt: generatedAt,
                limitId: limitId,
                windowDurationMins: currentSample.windowDurationMins,
                resetsAt: currentSample.resetsAt,
                currentUsedPercent: currentSample.usedPercent,
                usedPercentPerHour: nil,
                projectedFinalUsedPercent: nil,
                remainingSeconds: max(0, currentSample.resetsAt - currentSample.recordedAt),
                sampleCount: 1
            )
        }

        let usedDelta = max(0, currentSample.usedPercent - previousSample.usedPercent)
        let usedPercentPerSecond = usedDelta / Double(deltaSeconds)
        let usedPercentPerHour = usedPercentPerSecond * 60 * 60
        let remainingSeconds = max(0, currentSample.resetsAt - currentSample.recordedAt)
        let projectedFinalUsedPercent = currentSample.usedPercent +
            usedPercentPerSecond * Double(remainingSeconds)

        return CodexUsagePaceProjection(
            state: .projected,
            generatedAt: generatedAt,
            limitId: limitId,
            windowDurationMins: currentSample.windowDurationMins,
            resetsAt: currentSample.resetsAt,
            currentUsedPercent: currentSample.usedPercent,
            usedPercentPerHour: usedPercentPerHour,
            projectedFinalUsedPercent: projectedFinalUsedPercent,
            remainingSeconds: remainingSeconds,
            sampleCount: 2
        )
    }

    private func unavailableProjection(
        state: CodexUsagePaceProjectionState,
        generatedAt: Int
    ) -> CodexUsagePaceProjection {
        CodexUsagePaceProjection(
            state: state,
            generatedAt: generatedAt,
            limitId: nil,
            windowDurationMins: nil,
            resetsAt: nil,
            currentUsedPercent: nil,
            usedPercentPerHour: nil,
            projectedFinalUsedPercent: nil,
            remainingSeconds: nil,
            sampleCount: 0
        )
    }
}
