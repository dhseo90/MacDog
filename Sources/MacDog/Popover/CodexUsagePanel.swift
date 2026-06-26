import CodexUsageCore
import SwiftUI

struct CodexUsagePanel: View {
    let state: UsageMonitorState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let limit = state.codexLimit,
               let summary = state.codexPanelSummary(now: resetSummaryNow) {
                CodexUsageSummaryBlock(summary: summary, phase: state.phase)

                VStack(alignment: .leading, spacing: 8) {
                    UsageRow(
                        title: "5시간",
                        window: limit.fiveHour,
                        resetSummary: resetSummary(at: 0, in: summary)
                    )
                    UsageRow(
                        title: "주간",
                        window: limit.weekly,
                        resetSummary: resetSummary(at: 1, in: summary)
                    )
                }

                Divider()

                WeeklyRemainingHistoryBlock(
                    history: state.weeklyUsageHistory,
                    resetWindowHistory: state.resetWindowHistory,
                    weeklyWindow: limit.weekly,
                    currentReport: state.report,
                    currentTimestamp: state.cacheSnapshot?.cachedAt ?? state.report?.generatedAt
                )
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
    }

    private func resetSummary(at index: Int, in summary: CodexUsagePanelSummary) -> String? {
        guard summary.resetCountdowns.indices.contains(index) else { return nil }
        return summary.resetCountdowns[index].value
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

private struct CodexUsageSummaryBlock: View {
    let summary: CodexUsagePanelSummary
    let phase: UsagePressurePhase

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 3) {
                Text(summary.statusTitle)
                    .font(.caption.weight(.semibold))
                Text(summary.statusDetail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(summary.notificationThresholdSummary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 0)
        }
        .foregroundStyle(tint)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(tint.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(tint.opacity(0.24), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private var systemImage: String {
        switch phase {
        case .limit:
            "exclamationmark.octagon.fill"
        case .fast, .sprint:
            "exclamationmark.triangle.fill"
        case .calm, .active:
            "gauge.with.dots.needle.33percent"
        }
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
