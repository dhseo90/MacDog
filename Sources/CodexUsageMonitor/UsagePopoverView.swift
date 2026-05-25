import CodexUsageCore
import SwiftUI

struct UsagePopoverView: View {
    let state: UsageMonitorState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let limit = state.codexLimit {
                VStack(alignment: .leading, spacing: 10) {
                    UsageRow(title: "5h", window: limit.fiveHour)
                    UsageRow(title: "Weekly", window: limit.weekly)
                }

                Divider()

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    metadataRow("Plan", limit.planType ?? "unknown")
                    metadataRow("Credits", limit.credits?.balance ?? "unknown")
                    metadataRow("Source", state.sourceLabel)
                }
            } else {
                Text(state.errorMessage ?? "Usage unavailable")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let error = state.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .frame(width: 280, alignment: .leading)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(phaseColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text("Codex Usage")
                    .font(.headline)
                Text(state.phase.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var phaseColor: Color {
        switch state.phase {
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

    private func metadataRow(_ key: String, _ value: String) -> some View {
        GridRow {
            Text(key)
                .foregroundStyle(.secondary)
            Text(value)
                .lineLimit(1)
        }
        .font(.caption)
    }
}

private struct UsageRow: View {
    let title: String
    let window: UsageWindowReport?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progressValue)
                .tint(tint)

            Text(resetText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var summary: String {
        guard let window else { return "unavailable" }
        return "\(UsageMonitorState.percent(window.usedPercent))% used / \(UsageMonitorState.percent(window.remainingPercent))% left"
    }

    private var progressValue: Double {
        min(max((window?.usedPercent ?? 0) / 100, 0), 1)
    }

    private var resetText: String {
        guard let resetsAt = window?.resetsAt else { return "reset unknown" }
        let date = Date(timeIntervalSince1970: TimeInterval(resetsAt))
        return "resets \(date.formatted(date: .abbreviated, time: .shortened))"
    }

    private var tint: Color {
        switch window?.usedPercent ?? 0 {
        case 95...:
            .red
        case 80..<95:
            .orange
        case 50..<80:
            .accentColor
        default:
            .secondary
        }
    }
}

