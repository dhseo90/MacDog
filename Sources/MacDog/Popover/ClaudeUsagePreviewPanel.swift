import AppKit
import CodexUsageCore
import SwiftUI

enum ClaudeUsageHistoryGraphMode: String, CaseIterable, Identifiable {
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

struct ClaudeUsagePreviewPanel: View {
    let preview: ClaudeUsagePreviewState
    let now: Date

    @State private var selectedKind = ClaudeUsageWindowKind.sevenDay
    @State private var selectedMode = ClaudeUsageHistoryGraphMode.current
    @State private var selectedPastReset: Int?

    init(preview: ClaudeUsagePreviewState, now: Date = Date()) {
        self.preview = preview
        self.now = now
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            statusHeader

            if let usage = preview.usage {
                HStack(spacing: 8) {
                    usageCard(kind: .fiveHour, window: usage.fiveHour)
                    usageCard(kind: .sevenDay, window: usage.sevenDay)
                }

                paceSummary(for: usage)

                Divider()

                historyControls
                ClaudeUsageGraphSnapshotView(
                    kind: selectedKind,
                    mode: effectiveMode,
                    currentResetsAt: currentResetsAt,
                    pastResetsAt: effectivePastReset,
                    history: preview.history
                )
                .frame(height: 76)
            } else {
                waitingContent
            }

            Text("event-driven · 다음 Claude 응답 후 갱신 · live 구독 검수 미수행")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .accessibilityIdentifier("claude-usage-preview-panel")
    }

    private var statusHeader: some View {
        HStack(spacing: 6) {
            Text("Claude Usage")
                .font(.caption.weight(.semibold))
            Text("PREVIEW")
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.purple.opacity(0.18)))
                .foregroundStyle(Color.purple)
            Spacer(minLength: 0)
            Label(preview.statusTitle, systemImage: statusSystemImage)
                .font(.caption2.weight(.medium))
                .foregroundStyle(statusColor)
                .lineLimit(1)
        }
    }

    private func usageCard(
        kind: ClaudeUsageWindowKind,
        window: ClaudeUsageWindowSnapshot?
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(kind == .fiveHour ? "5시간" : "7일")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(window?.usedPercent.map { "\(UsageMonitorState.percent($0))% 사용" } ?? "사용량 대기")
                .font(.caption.weight(.semibold))
            Text(UsageWindowStatus.resetSummary(resetsAt: window?.resetsAt, now: now))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .padding(7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.045)))
    }

    private func paceSummary(for usage: ClaudeStatusLineSnapshot) -> some View {
        let projection = ClaudeUsagePaceProjectionBuilder().projection(
            kind: selectedKind,
            snapshot: usage,
            history: preview.history
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

    private var historyControls: some View {
        HStack(spacing: 6) {
            Picker("Window", selection: $selectedKind) {
                Text("5시간").tag(ClaudeUsageWindowKind.fiveHour)
                Text("7일").tag(ClaudeUsageWindowKind.sevenDay)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 86)

            Picker("기록", selection: $selectedMode) {
                ForEach(ClaudeUsageHistoryGraphMode.allCases) { mode in
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

            Button {
                copyGraph()
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.plain)
            .help("Claude Preview PNG 복사")

            Button {
                exportGraph()
            } label: {
                Image(systemName: "square.and.arrow.down")
            }
            .buttonStyle(.plain)
            .help("Claude Preview PNG 내보내기")
        }
        .controlSize(.mini)
    }

    private var waitingContent: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("status line event를 기다리는 중", systemImage: "hourglass")
                .font(.callout.weight(.medium))
            Text(preview.loadIssue ?? "bridge 연결 후 Claude가 응답하면 5시간/7일 사용량이 표시됩니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 28)
    }

    private var currentResetsAt: Int? {
        preview.usage?.window(selectedKind)?.resetsAt
    }

    private var pastResets: [Int] {
        preview.history.resetWindows(for: selectedKind)
            .filter { $0 != currentResetsAt }
            .sorted(by: >)
    }

    private var effectivePastReset: Int? {
        if let selectedPastReset, pastResets.contains(selectedPastReset) {
            return selectedPastReset
        }
        return pastResets.first
    }

    private var pastResetBinding: Binding<Int?> {
        Binding(
            get: { effectivePastReset },
            set: { selectedPastReset = $0 }
        )
    }

    private var effectiveMode: ClaudeUsageHistoryGraphMode {
        selectedMode == .current || effectivePastReset != nil ? selectedMode : .current
    }

    private var statusSystemImage: String {
        switch preview.status(now: now) {
        case .waiting: "hourglass"
        case .partial: "circle.lefthalf.filled"
        case .available: "checkmark.circle.fill"
        case .stale: "clock.badge.exclamationmark"
        case .error: "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch preview.status(now: now) {
        case .available: .green
        case .partial, .stale: .orange
        case .error: .red
        case .waiting: .secondary
        }
    }

    private func paceText(_ projection: ClaudeUsagePaceProjection) -> String {
        let label = projection.kind == .fiveHour ? "5시간" : "7일"
        switch projection.state {
        case .projected:
            let rate = projection.usedPercentPerHour.map { UsageMonitorState.percent($0) } ?? "-"
            let projected = projection.projectedFinalUsedPercent.map { UsageMonitorState.percent($0) } ?? "-"
            return "\(label) pace 시간당 \(rate)% · reset 시 \(projected)% 예상"
        case .waitingForSamples:
            return "\(label) pace 계산을 위한 다음 sample 대기"
        case .unavailable:
            return "\(label) pace 계산 불가"
        }
    }

    private func graphView() -> ClaudeUsageGraphSnapshotView {
        ClaudeUsageGraphSnapshotView(
            kind: selectedKind,
            mode: effectiveMode,
            currentResetsAt: currentResetsAt,
            pastResetsAt: effectivePastReset,
            history: preview.history
        )
    }

    private func copyGraph() {
        guard let data = CodexUsageGraphImageExporter.pngData(for: graphView()) else { return }
        CodexUsageGraphImageExporter.copyPNGData(data)
    }

    private func exportGraph() {
        guard let data = CodexUsageGraphImageExporter.pngData(for: graphView()) else { return }
        CodexUsageGraphImageExporter.exportPNGData(
            data,
            suggestedFileName: "macdog-claude-usage-\(selectedKind.rawValue)-\(effectiveMode.rawValue).png"
        )
    }
}

struct ClaudeUsageGraphSnapshotView: View {
    let kind: ClaudeUsageWindowKind
    let mode: ClaudeUsageHistoryGraphMode
    let currentResetsAt: Int?
    let pastResetsAt: Int?
    let history: ClaudeUsageHistory

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("Claude Preview · \(kind == .fiveHour ? "5시간" : "7일") 사용량")
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
                        history.samples(for: kind, resetsAt: currentResetsAt),
                        resetsAt: currentResetsAt,
                        color: .accentColor,
                        context: &context,
                        size: size
                    )
                }
                if mode != .current, let pastResetsAt {
                    drawSeries(
                        history.samples(for: kind, resetsAt: pastResetsAt),
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
        .accessibilityLabel("Claude Preview \(kind == .fiveHour ? "5시간" : "7일") \(mode.label) 사용량 그래프")
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
        _ samples: [ClaudeUsageHistorySample],
        resetsAt: Int,
        color: Color,
        context: inout GraphicsContext,
        size: CGSize
    ) {
        guard !samples.isEmpty else { return }
        let startsAt = resetsAt - kind.windowDurationMins * 60
        let duration = max(1, resetsAt - startsAt)
        var path = Path()
        for (index, sample) in samples.enumerated() {
            let xRatio = min(max(Double(sample.recordedAt - startsAt) / Double(duration), 0), 1)
            let yRatio = min(max(sample.usedPercent / 100, 0), 1)
            let point = CGPoint(
                x: size.width * xRatio,
                y: size.height * (1 - yRatio)
            )
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    }
}
