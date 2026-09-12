import CodexUsageCore
import SwiftUI

struct CodexUsagePanel: View {
    let state: UsageMonitorState

    var body: some View {
        VStack(alignment: .leading, spacing: CodexUsagePanelLayout.sectionSpacing) {
            if let limit = state.codexLimit,
               let summary = state.codexPanelSummary(now: resetSummaryNow) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("현재 사용량")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 6)
                    CodexUsageSummaryInline(
                        summary: summary,
                        phase: state.codexPhase,
                        selectedBasisLabel: state.selectedWindowStatus?.label
                    )
                }

                CodexWeeklyPacemakerBlock(
                    pacemaker: state.codexWeeklyPacemaker,
                    fiveHourPace: state.codexFiveHourPaceProjection
                )

                if UsageTabSectionVisibility.make(
                    mode: state.usageProviderMode,
                    selection: state.usageProviderSelection
                ).showsMainWeeklyGraph {
                    WeeklyRemainingHistoryBlock(
                        history: state.weeklyUsageHistory,
                        resetWindowHistory: state.resetWindowHistory,
                        weeklyWindow: limit.weekly,
                        currentReport: state.report,
                        currentTimestamp: state.cacheSnapshot?.cachedAt ?? state.report?.generatedAt,
                        graphHeight: CodexUsagePanelLayout.weeklyGraphHeight(
                            fiveHourIsAvailable: false
                        )
                    )
                }

                CodexResetCreditsBlock(resetCredits: state.report?.resetCredits)

                CodexUsageDataStatusBlock(status: state.codexDataStatus)
            } else if state.isRefreshing {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("사용량 새로고침 중...")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(state.errorMessage ?? "사용량을 확인할 수 없음")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let error = state.errorMessage, !state.isRefreshing {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .padding(.bottom, 0)
    }

    private var resetSummaryNow: Date {
        guard let report = state.report,
              report.source == "demo"
        else {
            return Date()
        }
        return Date(timeIntervalSince1970: TimeInterval(report.generatedAt))
    }
}

private struct CodexUsageSummaryInline: View {
    let summary: CodexUsagePanelSummary
    let phase: UsagePressurePhase
    let selectedBasisLabel: String?

    var body: some View {
        Text("\(summary.statusTitle) · \(basisText) · \(compactNotificationText)")
            .font(.caption2.weight(.medium))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.68)
            .help(summary.notificationThresholdSummary)
            .accessibilityLabel("\(summary.statusTitle), \(summary.statusDetail), \(summary.notificationThresholdSummary)")
            .accessibilityIdentifier("codex-usage-risk-notification-summary")
    }

    private var compactNotificationText: String {
        summary.notificationThresholdSummary
            .replacingOccurrences(of: "알림 기준 ", with: "알림 ")
            .components(separatedBy: " · ")
            .first ?? summary.notificationThresholdSummary
    }

    private var basisText: String {
        guard let selectedBasisLabel else { return "기준 확인 필요" }
        return "\(selectedBasisLabel) 기준"
    }

    private var tint: Color {
        switch phase {
        case .calm:
            .secondary
        case .active:
            .accentColor
        case .fast:
            .orange
        case .sprint, .limit:
            .red
        }
    }
}

private struct CodexUsageDataStatusBlock: View {
    let status: CodexUsageDataStatus

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Image(systemName: status.systemImage)
                .font(.caption2.weight(.semibold))
                .frame(width: 12)
            Text(status.title)
                .font(.caption2.weight(.semibold))
            Text(status.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Spacer(minLength: 0)
        }
        .foregroundStyle(tint)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(status.title), \(status.detail)")
    }

    private var tint: Color {
        switch status.tone {
        case .ok:
            .green
        case .waiting:
            .secondary
        case .warning:
            .orange
        case .error:
            .red
        }
    }
}
