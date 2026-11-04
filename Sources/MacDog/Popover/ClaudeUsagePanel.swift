import CodexUsageCore
import SwiftUI

struct ClaudeUsagePanel: View {
    let preview: ClaudeUsagePreviewState
    let now: Date
    let showsWeeklyGraph: Bool
    private let connectionGuide = ClaudeStatusLineConnectionGuide.bundled

    init(
        preview: ClaudeUsagePreviewState,
        now: Date = Date(),
        showsWeeklyGraph: Bool = true
    ) {
        self.preview = preview
        self.now = now
        self.showsWeeklyGraph = showsWeeklyGraph
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            statusHeader
            if let weekly = preview.currentWindow(.sevenDay, now: now),
               let weeklyWindow = ClaudeWeeklyRemainingHistoryAdapter.weeklyWindow(weekly) {
                if showsWeeklyGraph {
                    WeeklyRemainingHistoryBlock(
                        history: ClaudeWeeklyRemainingHistoryAdapter.history(
                            preview.history,
                            currentWeekly: weekly,
                            currentRecordedAt: preview.cacheSnapshot?.lastUsageObservedAt
                                ?? Int(now.timeIntervalSince1970)
                        ),
                        resetWindowHistory: .empty,
                        weeklyWindow: weeklyWindow,
                        currentReport: nil,
                        currentTimestamp: preview.cacheSnapshot?.lastUsageObservedAt
                            ?? Int(now.timeIntervalSince1970),
                        graphHeight: CodexUsagePanelLayout.weeklyGraphHeight(fiveHourIsAvailable: false)
                    )
                }
                paceSummary
            } else {
                waitingContent
            }
        }
        .accessibilityIdentifier("claude-usage-detail")
    }

    private var statusHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Image(systemName: statusSystemImage)
                .font(.caption2.weight(.semibold))
                .frame(width: 12)
            Text(preview.statusTitle(now: now))
                .font(.caption2.weight(.semibold))
            Spacer(minLength: 0)
        }
        .foregroundStyle(statusColor)
    }

    @ViewBuilder
    private var paceSummary: some View {
        if let usage = preview.usage {
            let projection = ClaudeUsagePaceProjectionBuilder().projection(
                kind: .sevenDay,
                snapshot: usage,
                history: preview.history
            )
            Text(paceText(projection))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func paceText(_ projection: ClaudeUsagePaceProjection) -> String {
        switch projection.state {
        case .projected:
            guard let rate = projection.usedPercentPerHour,
                  let projected = projection.projectedFinalUsedPercent else {
                return "주간 pace sample 대기"
            }
            return "주간 pace \(UsageMonitorState.percent(rate))%/h → \(UsageMonitorState.percent(projected))%"
        case .waitingForSamples:
            return "주간 pace sample 대기"
        case .unavailable:
            return "주간 pace 계산 안 함"
        }
    }

    private var waitingContent: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(
                preview.loadIssue == nil ? "연결 대기" : "cache 확인 필요",
                systemImage: preview.loadIssue == nil ? "link.badge.plus" : "exclamationmark.triangle"
            )
            .font(.callout.weight(.medium))
            Text(preview.loadIssue ?? "status line 연결 후 첫 응답부터 주간 사용량이 표시됩니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if preview.showsStatusLineBridge {
                Text(connectionGuide.standaloneCommand)
                    .font(.caption2.monospaced())
                    .textSelection(.enabled)
                    .lineLimit(2)
                Button("연결 명령 복사") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(connectionGuide.standaloneCommand, forType: .string)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 12)
    }

    private var statusSystemImage: String {
        switch preview.status(now: now) {
        case .available: "checkmark.circle.fill"
        case .partial: "circle.lefthalf.filled"
        case .waiting: "hourglass"
        case .stale: "clock.badge.exclamationmark"
        case .error: "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch preview.status(now: now) {
        case .available, .partial: .green
        case .waiting: .secondary
        case .stale, .error: .orange
        }
    }
}
