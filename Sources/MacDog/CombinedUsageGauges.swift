import CodexUsageCore
import Foundation
import SwiftUI

struct UsageProviderGaugeItem: Equatable, Identifiable {
    enum Kind: String, Equatable {
        case fiveHour
        case weekly
    }

    enum Value: Equatable {
        case ready(usedPercent: Double, remainingPercent: Double, resetsAt: Int?)
        case unavailable(String)
    }

    let provider: UsageProviderMode
    let kind: Kind
    let title: String
    let value: Value
    let isAuxiliary: Bool

    var id: String { "\(provider.rawValue)-\(kind.rawValue)-\(isAuxiliary)" }
}

struct CombinedUsageGaugeGroup: Equatable, Identifiable {
    let provider: UsageProviderMode
    let isAuxiliary: Bool
    let items: [UsageProviderGaugeItem]

    var id: String { "\(provider.rawValue)-\(isAuxiliary)" }
}

struct UsageTabSectionVisibility: Equatable {
    let showsCombinedGauges: Bool
    let showsPaceAndCredits: Bool
    let showsMainWeeklyGraph: Bool
    let showsDataStatus: Bool

    static func make(
        mode: UsageProviderMode,
        selection: UsageProviderSelection
    ) -> UsageTabSectionVisibility {
        if mode == .claude {
            return UsageTabSectionVisibility(
                showsCombinedGauges: false,
                showsPaceAndCredits: true,
                showsMainWeeklyGraph: true,
                showsDataStatus: true
            )
        }
        return UsageTabSectionVisibility(
            showsCombinedGauges: true,
            showsPaceAndCredits: true,
            showsMainWeeklyGraph: selection.detailGraphVisible,
            showsDataStatus: true
        )
    }
}

struct CombinedUsageGauges: Equatable {
    let groups: [CombinedUsageGaugeGroup]

    var items: [UsageProviderGaugeItem] {
        groups.flatMap(\.items)
    }

    static func make(state: UsageMonitorState, now: Date = Date()) -> CombinedUsageGauges {
        guard state.usageProviderMode != .claude else {
            return CombinedUsageGauges(groups: [])
        }

        let selection = state.usageProviderSelection
        switch state.runtimeProviderMode {
        case .codex:
            var groups = [codexGroup(state: state, isAuxiliary: false)]
            if selection.includesGrok {
                groups.append(grokGroup(state: state, now: now, isAuxiliary: true))
            }
            return CombinedUsageGauges(groups: groups)
        case .grok:
            var groups = [grokGroup(state: state, now: now, isAuxiliary: false)]
            if selection.includesCodex {
                groups.append(codexGroup(state: state, isAuxiliary: true))
            }
            return CombinedUsageGauges(groups: groups)
        case .claude:
            return CombinedUsageGauges(groups: [])
        }
    }

    private static func codexGroup(
        state: UsageMonitorState,
        isAuxiliary: Bool
    ) -> CombinedUsageGaugeGroup {
        var items: [UsageProviderGaugeItem] = []
        if !isAuxiliary, let fiveHour = readyValue(from: state.codexLimit?.fiveHour) {
            items.append(
                UsageProviderGaugeItem(
                    provider: .codex,
                    kind: .fiveHour,
                    title: "5시간",
                    value: fiveHour,
                    isAuxiliary: false
                )
            )
        }
        items.append(codexWeekly(state: state, isAuxiliary: isAuxiliary))
        return CombinedUsageGaugeGroup(provider: .codex, isAuxiliary: isAuxiliary, items: items)
    }

    private static func grokGroup(
        state: UsageMonitorState,
        now: Date,
        isAuxiliary: Bool
    ) -> CombinedUsageGaugeGroup {
        CombinedUsageGaugeGroup(
            provider: .grok,
            isAuxiliary: isAuxiliary,
            items: [grokWeekly(state: state, now: now, isAuxiliary: isAuxiliary)]
        )
    }

    private static func codexWeekly(
        state: UsageMonitorState,
        isAuxiliary: Bool
    ) -> UsageProviderGaugeItem {
        UsageProviderGaugeItem(
            provider: .codex,
            kind: .weekly,
            title: "주간",
            value: readyValue(from: state.codexLimit?.weekly) ?? .unavailable("주간 확인 불가"),
            isAuxiliary: isAuxiliary
        )
    }

    private static func grokWeekly(
        state: UsageMonitorState,
        now: Date,
        isAuxiliary: Bool
    ) -> UsageProviderGaugeItem {
        let preview = state.grokUsage
        let value: UsageProviderGaugeItem.Value
        if let weekly = preview.cacheSnapshot?.freshWeekly(now: now) {
            value = .ready(
                usedPercent: weekly.usedPercent,
                remainingPercent: weekly.remainingPercent,
                resetsAt: weekly.resetsAt
            )
        } else {
            value = .unavailable(grokUnavailableText(preview, now: now))
        }
        return UsageProviderGaugeItem(
            provider: .grok,
            kind: .weekly,
            title: "주간",
            value: value,
            isAuxiliary: isAuxiliary
        )
    }

    private static func readyValue(from window: UsageWindowReport?) -> UsageProviderGaugeItem.Value? {
        guard let window else { return nil }
        return .ready(
            usedPercent: window.usedPercent,
            remainingPercent: window.remainingPercent,
            resetsAt: window.resetsAt
        )
    }

    private static func grokUnavailableText(_ preview: GrokUsagePreviewState, now: Date) -> String {
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
}

struct CombinedUsageGaugesView: View {
    let gauges: CombinedUsageGauges
    let now: Date

    init(gauges: CombinedUsageGauges, now: Date = Date()) {
        self.gauges = gauges
        self.now = now
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(gauges.groups) { group in
                providerColumn(group)
            }
        }
        .accessibilityIdentifier("combined-usage-gauges")
    }

    private func providerColumn(_ group: CombinedUsageGaugeGroup) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(group.provider.label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(group.isAuxiliary ? .secondary : .primary)
            ForEach(group.items) { item in
                gaugeRow(item)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(group.isAuxiliary ? 0.03 : 0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(group.isAuxiliary ? 0.10 : 0.16), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(group.provider.label)
    }

    private func gaugeRow(_ item: UsageProviderGaugeItem) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(valueText(item.value))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
            if case let .ready(_, remainingPercent, _) = item.value {
                RemainingUsageBar(
                    value: min(max(remainingPercent / 100, 0), 1),
                    tint: barTint(remainingPercent: remainingPercent)
                )
                .accessibilityLabel("\(item.title) 남은 사용량")
                .accessibilityValue(valueText(item.value))
            }
            if let detail = detailText(item.value) {
                Text(detail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
        .accessibilityLabel(item.title)
        .accessibilityValue(valueText(item.value))
    }

    private func barTint(remainingPercent: Double) -> Color {
        switch remainingPercent {
        case ..<10:
            .red
        case 10..<30:
            .orange
        case 30..<60:
            .yellow
        default:
            .green
        }
    }

    private func valueText(_ value: UsageProviderGaugeItem.Value) -> String {
        switch value {
        case let .ready(usedPercent, remainingPercent, _):
            "\(UsageMonitorState.percent(usedPercent))% 사용 · \(UsageMonitorState.percent(remainingPercent))% 남음"
        case let .unavailable(detail):
            detail
        }
    }

    private func detailText(_ value: UsageProviderGaugeItem.Value) -> String? {
        switch value {
        case let .ready(_, _, resetsAt):
            UsageWindowStatus.resetSummary(resetsAt: resetsAt, now: now)
        case .unavailable:
            nil
        }
    }
}
