import AppKit
import CodexUsageCore
import SwiftUI

struct CodexUsagePanel: View {
    let state: UsageMonitorState
    var minimumColumnHeight: CGFloat?

    init(state: UsageMonitorState, minimumColumnHeight: CGFloat? = nil) {
        self.state = state
        self.minimumColumnHeight = minimumColumnHeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let limit = state.codexLimit {
                let showsResetCredit = CodexResetCreditTextFormatter.showsRow(state.report?.resetCredits)
                let remainingCreditText = CodexRemainingCreditTextFormatter.displayText(for: limit.credits)
                let showsGraph = UsageTabSectionVisibility.make(
                    mode: state.usageProviderMode,
                    selection: state.usageProviderSelection
                ).showsMainWeeklyGraph
                if showsGraph {
                    CodexUsageDetailStack(
                        state: state,
                        minimumColumnHeight: minimumColumnHeight,
                        showsResetCredit: showsResetCredit,
                        remainingCreditText: remainingCreditText,
                        status: statusBlock
                    )
                } else {
                    if showsResetCredit, let resetCredits = state.report?.resetCredits {
                        CodexResetCreditsBlock(resetCredits: resetCredits)
                    }
                    if let remainingCreditText {
                        CodexRemainingCreditsBlock(text: remainingCreditText)
                    }
                    statusBlock
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
                if let error = state.errorMessage, !state.isRefreshing {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }
        }
        .padding(.bottom, 0)
    }

    private var statusBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            CodexUsageDataStatusBlock(status: state.codexDataStatus)
            if let error = state.errorMessage, !state.isRefreshing {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .background(MacDogLayoutProbe(name: "codex-data-status"))
    }
}

struct MacDogLayoutProbe: NSViewRepresentable {
    var name: String

    func makeNSView(context: Context) -> NSView {
        let view = MacDogLayoutProbeView(frame: .zero)
        view.identifier = NSUserInterfaceItemIdentifier(name)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.identifier = NSUserInterfaceItemIdentifier(name)
    }
}

private final class MacDogLayoutProbeView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

private struct CodexDetailHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Graph, then reset credits, then remaining credits, then a short gap and the data status.
/// Spare column height is added to the weekly plot on the next layout pass.
private struct CodexUsageDetailStack<Status: View>: View {
    let state: UsageMonitorState
    var minimumColumnHeight: CGFloat?
    let showsResetCredit: Bool
    let remainingCreditText: String?
    let status: Status
    @State private var graphHeightBoost: CGFloat = 0

    var body: some View {
        let baseGraphHeight = CodexUsagePanelLayout.weeklyGraphHeight(
            fiveHourIsAvailable: state.codexLimit?.fiveHour != nil,
            showsResetCredit: showsResetCredit,
            showsRemainingCredit: remainingCreditText != nil
        )
        VStack(alignment: .leading, spacing: 0) {
            WeeklyRemainingHistoryBlock(
                history: state.weeklyUsageHistory,
                resetWindowHistory: state.resetWindowHistory,
                weeklyWindow: state.codexLimit?.weekly,
                currentReport: state.report,
                currentTimestamp: state.cacheSnapshot?.cachedAt ?? state.report?.generatedAt,
                graphHeight: baseGraphHeight + graphHeightBoost
            )
            if showsResetCredit, let resetCredits = state.report?.resetCredits {
                CodexResetCreditsBlock(resetCredits: resetCredits)
                    .background(MacDogLayoutProbe(name: "codex-reset-credits"))
                    .padding(.top, CodexUsagePanelLayout.detailGraphSpacing)
            }
            if let remainingCreditText {
                CodexRemainingCreditsBlock(text: remainingCreditText)
                    .background(MacDogLayoutProbe(name: "codex-remaining-credits"))
                    .padding(
                        .top,
                        showsResetCredit
                            ? CodexUsagePanelLayout.detailCardSpacing
                            : CodexUsagePanelLayout.detailGraphSpacing
                    )
            }
            status
                .padding(.top, CodexUsagePanelLayout.detailStatusSpacing)
        }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: CodexDetailHeightKey.self, value: proxy.size.height)
            }
        }
        .onPreferenceChange(CodexDetailHeightKey.self) { contentHeight in
            guard let minimumColumnHeight, contentHeight > 0 else { return }
            let nextBoost = max(0, graphHeightBoost + minimumColumnHeight - contentHeight)
            if abs(nextBoost - graphHeightBoost) > 0.5 {
                graphHeightBoost = nextBoost
            }
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
