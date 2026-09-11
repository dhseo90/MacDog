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
    let items: [UsageProviderGaugeItem]

    static func make(state: UsageMonitorState, now: Date = Date()) -> CombinedUsageGauges {
        guard state.usageProviderMode != .claude else {
            return CombinedUsageGauges(items: [])
        }

        let selection = state.usageProviderSelection
        switch state.runtimeProviderMode {
        case .codex:
            var items = [
                codexFiveHour(state: state, isAuxiliary: false),
                codexWeekly(state: state, isAuxiliary: false)
            ]
            if selection.includesGrok {
                items.append(grokWeekly(state: state, now: now, isAuxiliary: true))
            }
            return CombinedUsageGauges(items: items)
        case .grok:
            var items = [grokWeekly(state: state, now: now, isAuxiliary: false)]
            if selection.includesCodex {
                items.append(codexWeekly(state: state, isAuxiliary: true))
            }
            return CombinedUsageGauges(items: items)
        case .claude:
            return CombinedUsageGauges(items: [])
        }
    }

    private static func codexFiveHour(
        state: UsageMonitorState,
        isAuxiliary: Bool
    ) -> UsageProviderGaugeItem {
        UsageProviderGaugeItem(
            provider: .codex,
            kind: .fiveHour,
            title: isAuxiliary ? "Codex 5시간" : "5시간",
            value: readyValue(from: state.codexLimit?.fiveHour) ?? .unavailable("현재 제공되지 않음"),
            isAuxiliary: isAuxiliary
        )
    }

    private static func codexWeekly(
        state: UsageMonitorState,
        isAuxiliary: Bool
    ) -> UsageProviderGaugeItem {
        UsageProviderGaugeItem(
            provider: .codex,
            kind: .weekly,
            title: isAuxiliary ? "Codex 주간" : "주간",
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
            title: isAuxiliary ? "Grok 주간" : "주간",
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
        HStack(alignment: .top, spacing: 6) {
            ForEach(gauges.items) { item in
                gaugeCard(item)
            }
        }
        .accessibilityIdentifier("combined-usage-gauges")
    }

    private func gaugeCard(_ item: UsageProviderGaugeItem) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(valueText(item.value))
                .font(.caption.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.76)
            if let detail = detailText(item.value) {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
        }
        .padding(7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.045)))
        .accessibilityLabel(item.title)
        .accessibilityValue(valueText(item.value))
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
