import CodexUsageCore
import SwiftUI

struct CodexUsagePanel: View {
    let state: UsageMonitorState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let limit = state.codexLimit {
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
                            fiveHourIsAvailable: limit.fiveHour != nil
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
