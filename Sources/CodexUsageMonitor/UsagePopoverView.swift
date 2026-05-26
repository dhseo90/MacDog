import CodexUsageCore
import SwiftUI

struct UsagePopoverView: View {
    let state: UsageMonitorState
    let onPreferencesChanged: () -> Void

    init(state: UsageMonitorState, onPreferencesChanged: @escaping () -> Void = {}) {
        self.state = state
        self.onPreferencesChanged = onPreferencesChanged
    }

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
            } else if state.isRefreshing {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Refreshing usage...")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(state.errorMessage ?? "Usage unavailable")
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

            RunnerControls(onChange: onPreferencesChanged)
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

private struct RunnerControls: View {
    let onChange: () -> Void

    @AppStorage(RunnerPreferences.displayBasisKey) private var displayBasis = RunnerPreferences.defaultDisplayBasis.rawValue
    @AppStorage(RunnerPreferences.reducedMotionKey) private var reducedMotion = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            controlLabel("Runner speed")
            Picker("Runner speed", selection: $displayBasis) {
                ForEach(UsageDisplayBasis.allCases) { basis in
                    Text(basis.label).tag(basis.rawValue)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .help("Choose which usage window controls the runner speed.")

            Toggle("Reduce motion", isOn: $reducedMotion)
                .font(.caption)
        }
        .onChange(of: displayBasis) { _, _ in onChange() }
        .onChange(of: reducedMotion) { _, _ in onChange() }
    }

    private func controlLabel(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
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
