import AppKit
import CodexUsageCore
import SwiftUI

struct GrokUsagePanel: View {
    let preview: GrokUsagePreviewState
    let now: Date
    private let loginGuide = GrokLoginGuide()

    init(preview: GrokUsagePreviewState, now: Date = Date()) {
        self.preview = preview
        self.now = now
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            statusHeader
            windowCards
            if let weekly = preview.cacheSnapshot?.freshWeekly(now: now) {
                paceSummary(for: weekly)
                Divider()
                WeeklyRemainingHistoryBlock(
                    history: GrokWeeklyRemainingHistoryAdapter.history(
                        preview.history,
                        currentWeekly: weekly,
                        currentRecordedAt: preview.cacheSnapshot?.lastUsageObservedAt
                            ?? Int(now.timeIntervalSince1970)
                    ),
                    resetWindowHistory: .empty,
                    weeklyWindow: GrokWeeklyRemainingHistoryAdapter.weeklyWindow(weekly),
                    currentReport: nil,
                    currentTimestamp: preview.cacheSnapshot?.lastUsageObservedAt
                        ?? Int(now.timeIntervalSince1970),
                    graphHeight: CodexUsagePanelLayout.weeklyGraphHeight(fiveHourIsAvailable: false)
                )
            } else {
                waitingContent
            }
        }
        .accessibilityIdentifier("grok-usage-panel")
    }

    private var statusHeader: some View {
        HStack(spacing: 6) {
            Text("Grok 사용량")
                .font(.caption.weight(.semibold))
            Spacer(minLength: 0)
            Label(preview.statusTitle(now: now), systemImage: statusSystemImage)
                .font(.caption2.weight(.medium))
                .foregroundStyle(statusColor)
                .lineLimit(1)
        }
    }

    private var windowCards: some View {
        windowCard(
            title: "주간",
            value: weeklySummary,
            detail: UsageWindowStatus.resetSummary(
                resetsAt: preview.cacheSnapshot?.freshWeekly(now: now)?.resetsAt,
                now: now
            )
        )
    }

    private func windowCard(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.semibold))
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .padding(7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.045)))
    }

    private var weeklySummary: String {
        guard let weekly = preview.cacheSnapshot?.freshWeekly(now: now) else {
            return unavailableWeeklyText
        }
        return "\(UsageMonitorState.percent(weekly.usedPercent))% 사용 · \(UsageMonitorState.percent(weekly.remainingPercent))% 남음"
    }

    private var unavailableWeeklyText: String {
        if let text = preview.weeklyCardUnavailableText() {
            return text
        }
        switch preview.status(now: now) {
        case .stale:
            return "오래된 cache · 갱신 대기"
        case .error:
            return "cache 확인 필요"
        case .waiting, .available:
            return "주간 cache 없음"
        }
    }

    private func paceSummary(for weekly: GrokUsageWeeklyWindow) -> some View {
        let projection = GrokUsagePaceProjectionBuilder().projection(
            weekly: weekly,
            history: preview.history,
            now: Int(now.timeIntervalSince1970)
        )
        return HStack(spacing: 5) {
            Image(systemName: "gauge.with.dots.needle.50percent")
            Text(paceText(projection))
                .lineLimit(1)
                .minimumScaleFactor(0.76)
            Spacer(minLength: 0)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func paceText(_ projection: GrokUsagePaceProjection) -> String {
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
                preview.emptyStateTitle(),
                systemImage: preview.loadIssue == nil ? "link.badge.plus" : "exclamationmark.triangle"
            )
            .font(.callout.weight(.medium))
            Text(preview.emptyStateDetail())
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if preview.showsLoginActions {
                HStack(spacing: 8) {
                    Button("로그인 명령 복사") {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(loginGuide.standaloneCommand, forType: .string)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("메뉴바는 auth.json을 읽지 않고 grok login 명령만 복사합니다.")

                    Button("터미널에서 로그인") {
                        try? loginGuide.openTerminal()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Terminal에서 grok login을 엽니다. 메뉴바는 auth.json을 읽지 않습니다.")
                }
            }
        }
        .padding(.vertical, 12)
    }

    private var statusSystemImage: String {
        switch preview.status(now: now) {
        case .available: "checkmark.circle.fill"
        case .waiting: "hourglass"
        case .stale: "clock.badge.exclamationmark"
        case .error: "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch preview.status(now: now) {
        case .available: .secondary
        case .waiting: .secondary
        case .stale: .orange
        case .error: .orange
        }
    }
}
