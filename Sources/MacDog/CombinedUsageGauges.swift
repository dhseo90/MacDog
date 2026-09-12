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

protocol UsageGaugeQuerying {
    var provider: UsageProviderMode { get }
    func windows(from state: UsageMonitorState, now: Date, isAuxiliary: Bool) -> [UsageProviderGaugeItem]
}

enum UsageGaugeQueryCatalog {
    static var visibleQueries: [any UsageGaugeQuerying] {
        [CodexUsageGaugeQuery(), GrokUsageGaugeQuery()]
    }

    static func displayOrder(
        main: UsageProviderMode,
        selection: UsageProviderSelection
    ) -> [any UsageGaugeQuerying] {
        let enabledQueries = visibleQueries.filter { query in
            selection.includes(query.provider)
        }
        guard let mainQuery = enabledQueries.first(where: { $0.provider == main }) else {
            return enabledQueries
        }
        return [mainQuery] + enabledQueries.filter { $0.provider != main }
    }
}

struct CodexUsageGaugeQuery: UsageGaugeQuerying {
    let provider = UsageProviderMode.codex

    func windows(from state: UsageMonitorState, now _: Date, isAuxiliary: Bool) -> [UsageProviderGaugeItem] {
        var items = [Self.weekly(state: state, isAuxiliary: isAuxiliary)]
        if !isAuxiliary, let fiveHour = Self.readyValue(from: state.codexLimit?.fiveHour) {
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
        return items
    }

    private static func weekly(state: UsageMonitorState, isAuxiliary: Bool) -> UsageProviderGaugeItem {
        UsageProviderGaugeItem(
            provider: .codex,
            kind: .weekly,
            title: "주간",
            value: readyValue(from: state.codexLimit?.weekly) ?? .unavailable("주간 확인 불가"),
            isAuxiliary: isAuxiliary
        )
    }

    fileprivate static func readyValue(from window: UsageWindowReport?) -> UsageProviderGaugeItem.Value? {
        guard let window else { return nil }
        return .ready(
            usedPercent: window.usedPercent,
            remainingPercent: window.remainingPercent,
            resetsAt: window.resetsAt
        )
    }
}

struct GrokUsageGaugeQuery: UsageGaugeQuerying {
    let provider = UsageProviderMode.grok

    func windows(from state: UsageMonitorState, now: Date, isAuxiliary: Bool) -> [UsageProviderGaugeItem] {
        [weekly(state: state, now: now, isAuxiliary: isAuxiliary)]
    }

    private func weekly(
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
            value = .unavailable(Self.unavailableText(preview, now: now))
        }
        return UsageProviderGaugeItem(
            provider: .grok,
            kind: .weekly,
            title: "주간",
            value: value,
            isAuxiliary: isAuxiliary
        )
    }

    private static func unavailableText(_ preview: GrokUsagePreviewState, now: Date) -> String {
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

enum CombinedUsageGaugeMetrics {
    static let windowTitleWidth: CGFloat = 34
    static let percentWidth: CGFloat = 30
}

enum CombinedUsageGaugeCopy {
    static func usedText(usedPercent: Double) -> String {
        "\(UsageMonitorState.percent(usedPercent))% 사용"
    }

    static func remainingText(remainingPercent: Double) -> String {
        "\(UsageMonitorState.percent(remainingPercent))% 남음"
    }

    static func usageText(_ value: UsageProviderGaugeItem.Value) -> String {
        switch value {
        case let .ready(usedPercent, remainingPercent, _):
            "\(usedText(usedPercent: usedPercent)) \(remainingText(remainingPercent: remainingPercent))"
        case let .unavailable(detail):
            detail
        }
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

        let main = state.runtimeProviderMode
        let groups = UsageGaugeQueryCatalog.displayOrder(
            main: main,
            selection: state.usageProviderSelection
        ).compactMap { query -> CombinedUsageGaugeGroup? in
            let isAuxiliary = query.provider != main
            let items = query.windows(from: state, now: now, isAuxiliary: isAuxiliary)
            guard !items.isEmpty else { return nil }
            return CombinedUsageGaugeGroup(
                provider: query.provider,
                isAuxiliary: isAuxiliary,
                items: items
            )
        }
        return CombinedUsageGauges(groups: groups)
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
        VStack(alignment: .leading, spacing: 4) {
            ForEach(gauges.groups) { group in
                providerCard(group)
            }
        }
        .accessibilityIdentifier("combined-usage-gauges")
    }

    private func providerCard(_ group: CombinedUsageGaugeGroup) -> some View {
        let accent = providerAccent(group.provider)
        return VStack(alignment: .leading, spacing: 2) {
            Text(group.provider.label)
                .font(Self.rowFont.weight(.semibold))
                .foregroundStyle(group.isAuxiliary ? .secondary : accent)
            ForEach(group.items) { item in
                compactRow(item, accent: accent)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(accent.opacity(group.isAuxiliary ? 0.06 : 0.11))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(accent.opacity(group.isAuxiliary ? 0.20 : 0.34), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(group.provider.label)
    }

    private func compactRow(
        _ item: UsageProviderGaugeItem,
        accent: Color
    ) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(accent)
                .frame(width: 3, height: 11)
            Text(item.title)
                .font(Self.rowFont.weight(.semibold))
                .frame(width: CombinedUsageGaugeMetrics.windowTitleWidth, alignment: .leading)
            usageValue(item.value)
            Spacer(minLength: 2)
            Text(resetText(item.value))
                .font(Self.rowFont)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .accessibilityLabel("\(item.provider.label) \(item.title)")
        .accessibilityValue("\(CombinedUsageGaugeCopy.usageText(item.value)) \(resetText(item.value))")
    }

    @ViewBuilder
    private func usageValue(_ value: UsageProviderGaugeItem.Value) -> some View {
        switch value {
        case let .ready(usedPercent, remainingPercent, _):
            HStack(spacing: 6) {
                percentPair(value: usedPercent, label: "사용", color: .secondary)
                percentPair(value: remainingPercent, label: "남음", color: Self.remainingColor)
            }
            .fixedSize(horizontal: true, vertical: false)
        case let .unavailable(detail):
            Text(detail)
                .font(Self.rowFont)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func percentPair(value: Double, label: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Text("\(UsageMonitorState.percent(value))%")
                .font(Self.rowDigitFont)
                .frame(width: CombinedUsageGaugeMetrics.percentWidth, alignment: .trailing)
                .lineLimit(1)
            Text(label)
                .font(Self.rowFont)
                .lineLimit(1)
                .fixedSize()
        }
        .foregroundStyle(color)
        .fixedSize(horizontal: true, vertical: false)
    }

    private func providerAccent(_ provider: UsageProviderMode) -> Color {
        switch provider {
        case .codex:
            Color(red: 0.20, green: 0.48, blue: 0.86)
        case .grok:
            Color(red: 0.86, green: 0.45, blue: 0.16)
        case .claude:
            Color.secondary
        }
    }

    private static let rowFont = Font.caption2
    private static let rowDigitFont = Font.caption2.monospacedDigit()
    private static let remainingColor = Color.green

    private func resetText(_ value: UsageProviderGaugeItem.Value) -> String {
        switch value {
        case let .ready(_, _, resetsAt):
            UsageWindowStatus.resetDateLabel(resetsAt: resetsAt, now: now)
        case .unavailable:
            ""
        }
    }
}
