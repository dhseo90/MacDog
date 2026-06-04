import CodexUsageCore
import SwiftUI

struct CodexUsagePanel: View {
    let state: UsageMonitorState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let limit = state.codexLimit {
                VStack(alignment: .leading, spacing: 12) {
                    UsageRow(title: "5시간", window: limit.fiveHour)
                    UsageRow(title: "주간", window: limit.weekly)
                }

                Divider()

                WeeklyRemainingHistoryBlock(
                    history: state.weeklyUsageHistory,
                    weeklyWindow: limit.weekly,
                    currentReport: state.report,
                    currentTimestamp: state.cacheSnapshot?.cachedAt ?? state.report?.generatedAt
                )

                if let message = state.highUsageMessage {
                    PressureBanner(message: message, phase: state.phase)
                }

                Divider()

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    metadataRow("플랜", limit.planType ?? "알 수 없음")
                    metadataRow("갱신", state.lastUpdatedSummary)
                    resetMetadataRow(limit.weekly)
                }
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

    private func metadataRow(_ key: String, _ value: String) -> some View {
        GridRow {
            Text(key)
                .foregroundStyle(.secondary)
            Text(value)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption)
    }

    private func resetMetadataRow(_ window: UsageWindowReport?) -> some View {
        metadataRow("초기화", resetMetadataValue(window))
    }

    private func resetMetadataValue(_ window: UsageWindowReport?) -> String {
        let summary = UsageWindowStatus.resetSummary(
            resetsAt: window?.resetsAt,
            now: resetSummaryNow
        )
        if summary.hasPrefix("초기화까지 ") {
            return String(summary.dropFirst("초기화까지 ".count))
        }
        if summary.hasPrefix("초기화 ") {
            return String(summary.dropFirst("초기화 ".count))
        }
        return summary
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
