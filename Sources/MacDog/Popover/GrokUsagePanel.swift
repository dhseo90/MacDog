import CodexUsageCore
import SwiftUI

enum GrokUsageHistoryGraphMode: String, CaseIterable, Identifiable {
    case current
    case past
    case compare

    var id: String { rawValue }

    var label: String {
        switch self {
        case .current: "현재"
        case .past: "지난"
        case .compare: "비교"
        }
    }
}

struct GrokUsagePanel: View {
    let preview: GrokUsagePreviewState
    let now: Date

    @State private var selectedMode = GrokUsageHistoryGraphMode.current
    @State private var selectedPastReset: Int?

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
                historyControls
                GrokUsageGraphSnapshotView(
                    mode: effectiveMode,
                    currentResetsAt: weekly.resetsAt,
                    pastResetsAt: effectivePastReset,
                    history: preview.history
                )
                .frame(height: 76)
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
        HStack(spacing: 8) {
            windowCard(
                title: "5시간",
                value: "현재 제공되지 않음",
                detail: "합성하지 않음"
            )
            windowCard(
                title: "주간",
                value: weeklySummary,
                detail: UsageWindowStatus.resetSummary(
                    resetsAt: preview.cacheSnapshot?.freshWeekly(now: now)?.resetsAt,
                    now: now
                )
            )
        }
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

    private var historyControls: some View {
        HStack(spacing: 6) {
            Picker("기록", selection: $selectedMode) {
                ForEach(GrokUsageHistoryGraphMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            if effectiveMode != .current, pastResets.count > 1 {
                Picker("지난 window", selection: pastResetBinding) {
                    ForEach(pastResets, id: \.self) { resetsAt in
                        Text(Date(timeIntervalSince1970: TimeInterval(resetsAt)).formatted(
                            date: .abbreviated,
                            time: .omitted
                        ))
                        .tag(Optional(resetsAt))
                    }
                }
                .labelsHidden()
                .frame(width: 72)
            }
            Spacer(minLength: 0)
        }
        .controlSize(.mini)
    }

    private var waitingContent: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(
                preview.loadIssue == nil ? "Grok 주간 cache 없음" : "Grok cache 확인 필요",
                systemImage: preview.loadIssue == nil ? "hourglass" : "exclamationmark.triangle"
            )
            .font(.callout.weight(.medium))
            Text(preview.loadIssue ?? "Grok mode에서 writer가 첫 주간 sample을 쓰면 사용량이 표시됩니다. Codex cache로 대체하지 않습니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 12)
    }

    private var pastResets: [Int] {
        let current = preview.cacheSnapshot?.weekly?.resetsAt
        return preview.history.resetWindows().filter { $0 != current }
    }

    private var effectiveMode: GrokUsageHistoryGraphMode {
        if selectedMode != .current, pastResets.isEmpty {
            return .current
        }
        return selectedMode
    }

    private var effectivePastReset: Int? {
        selectedPastReset ?? pastResets.last
    }

    private var pastResetBinding: Binding<Int?> {
        Binding(
            get: { effectivePastReset },
            set: { selectedPastReset = $0 }
        )
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

struct GrokUsageGraphSnapshotView: View {
    let mode: GrokUsageHistoryGraphMode
    let currentResetsAt: Int?
    let pastResetsAt: Int?
    let history: GrokUsageHistory

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("Grok · 주간 잔여량")
                    .font(.caption2.weight(.semibold))
                Spacer()
                Text(mode.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Canvas { context, size in
                drawGrid(context: &context, size: size)
                if mode != .past, let currentResetsAt {
                    drawSeries(
                        history.samples(resetsAt: currentResetsAt),
                        resetsAt: currentResetsAt,
                        color: .accentColor,
                        context: &context,
                        size: size
                    )
                }
                if mode != .current, let pastResetsAt {
                    drawSeries(
                        history.samples(resetsAt: pastResetsAt),
                        resetsAt: pastResetsAt,
                        color: .secondary,
                        context: &context,
                        size: size
                    )
                }
            }
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.035)))
        }
        .padding(6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Grok 주간 \(mode.label) 잔여량 그래프")
    }

    private func drawGrid(context: inout GraphicsContext, size: CGSize) {
        for ratio in [0.25, 0.5, 0.75] {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height * ratio))
            path.addLine(to: CGPoint(x: size.width, y: size.height * ratio))
            context.stroke(path, with: .color(.secondary.opacity(0.16)), lineWidth: 0.5)
        }
    }

    private func drawSeries(
        _ samples: [GrokUsageHistorySample],
        resetsAt: Int,
        color: Color,
        context: inout GraphicsContext,
        size: CGSize
    ) {
        guard !samples.isEmpty else { return }
        let startsAt = resetsAt - GrokUsagePaceProjectionBuilder.weeklyWindowDurationSeconds
        let duration = max(1, resetsAt - startsAt)
        var path = Path()
        var previousRemaining = 100.0
        for (index, sample) in samples.enumerated() {
            let remaining = min(previousRemaining, sample.remainingPercent)
            previousRemaining = remaining
            let xRatio = min(max(Double(sample.recordedAt - startsAt) / Double(duration), 0), 1)
            let yRatio = min(max(remaining / 100, 0), 1)
            let point = CGPoint(
                x: size.width * xRatio,
                y: size.height * (1 - yRatio)
            )
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    }
}
