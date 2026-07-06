import CodexUsageCore
import Foundation
import SwiftUI

struct CodexResetCreditsBlock: View {
    let resetCredits: RateLimitResetCreditsSummary?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Label("사용자 초기화권", systemImage: "arrow.counterclockwise.circle.fill")
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 6)
                Text(CodexResetCreditTextFormatter.countText(for: resetCredits))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            if let resetCredits {
                resetCreditDetails(for: resetCredits)
            } else {
                resetCreditPlaceholder("초기화권 정보 미확인")
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(tint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private func resetCreditDetails(for resetCredits: RateLimitResetCreditsSummary) -> some View {
        if resetCredits.availableCount <= 0 {
            resetCreditPlaceholder("사용 가능한 초기화권 없음")
        } else if resetCredits.credits.isEmpty {
            resetCreditPlaceholder("만료일 갱신 필요")
        } else {
            let items = CodexResetCreditTextFormatter.displayItems(for: resetCredits)
            VStack(alignment: .leading, spacing: 4) {
                if resetCredits.credits.count <= 2 {
                    ForEach(items) { item in
                        resetCreditItemCell(item)
                    }
                } else {
                    let rows = Array(items.prefix(6)).chunked(into: 2)
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            ForEach(row) { item in
                                resetCreditItemCell(item)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            if row.count == 1 {
                                Spacer(minLength: 0)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }

                    let hiddenKnownCount = items.count - min(6, items.count)
                    if hiddenKnownCount > 0 {
                        Text("외 \(hiddenKnownCount)장")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                    }
                }

                let unknownCount = resetCredits.availableCount - items.count
                if unknownCount > 0 {
                    Text("나머지 \(unknownCount)장 만료일 갱신 필요")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
        }
    }

    private func resetCreditItemCell(_ item: CodexResetCreditDisplayItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if item.isFirstExpiring {
                Text("먼저")
                    .font(.caption2)
                    .foregroundStyle(item.urgency.tint)
                    .frame(width: 25, alignment: .leading)
            } else {
                Color.clear
                    .frame(width: 25, height: 1)
                    .accessibilityHidden(true)
            }
            Text(item.expiryText)
                .font(.caption2)
                .foregroundStyle(item.urgency.tint)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
    }

    private func resetCreditPlaceholder(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "info.circle")
                .font(.caption2.weight(.semibold))
                .frame(width: 12)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
            Spacer(minLength: 0)
        }
    }

    private var tint: Color {
        guard let resetCredits else { return .secondary }
        return resetCredits.availableCount > 0 ? .accentColor : .secondary
    }

    private var accessibilityLabel: String {
        guard let resetCredits else { return "사용자 초기화권, 정보 미확인" }
        return "사용자 초기화권, \(CodexResetCreditTextFormatter.countText(for: resetCredits)), \(CodexResetCreditTextFormatter.expirySummary(for: resetCredits))"
    }
}

struct CodexResetCreditDisplayItem: Identifiable, Equatable {
    let index: Int
    let expiryText: String
    let isFirstExpiring: Bool
    let urgency: CodexResetCreditUrgency

    var id: Int { index }
}

enum CodexResetCreditUrgency: Equatable {
    case normal
    case soon
    case urgent

    var tint: Color {
        switch self {
        case .normal:
            .secondary
        case .soon:
            .orange
        case .urgent:
            .red
        }
    }
}

struct CodexResetCreditTextFormatter {
    static func countText(for summary: RateLimitResetCreditsSummary?) -> String {
        guard let summary else { return "정보 갱신 필요" }
        if summary.availableCount <= 0 { return "초기화권 없음" }
        return "\(summary.availableCount)장"
    }

    static func expirySummary(
        for summary: RateLimitResetCreditsSummary?,
        timeZone: TimeZone = .current,
        locale: Locale = .current
    ) -> String {
        guard let summary else { return "정보 미확인" }
        if summary.availableCount <= 0 { return "사용 가능한 초기화권 없음" }

        let expiries = displayItems(for: summary, timeZone: timeZone, locale: locale).map { item in
            item.isFirstExpiring ? "먼저 \(item.expiryText)" : item.expiryText
        }

        guard !expiries.isEmpty else {
            return "만료일 갱신 필요"
        }
        return expiries.joined(separator: " · ")
    }

    static func expiryText(
        for credit: RateLimitResetCredit,
        timeZone: TimeZone = .current,
        locale: Locale = .current
    ) -> String {
        guard let expiresAt = credit.expiresAt, !expiresAt.isEmpty else {
            return "만료일 갱신 필요"
        }
        guard let date = parseISO8601Date(expiresAt) else {
            return "\(expiresAt)까지"
        }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "M/d HH:mm'까지'"
        return formatter.string(from: date)
    }

    static func displayItems(
        for summary: RateLimitResetCreditsSummary,
        timeZone: TimeZone = .current,
        locale: Locale = .current,
        now: Date = Date()
    ) -> [CodexResetCreditDisplayItem] {
        let datedCredits = summary.credits.compactMap { credit -> (credit: RateLimitResetCredit, date: Date)? in
            guard let expiresAt = credit.expiresAt,
                  let date = parseISO8601Date(expiresAt) else {
                return nil
            }
            return (credit, date)
        }
        .sorted { lhs, rhs in
            lhs.date < rhs.date
        }

        return datedCredits.enumerated().map { index, entry in
            CodexResetCreditDisplayItem(
                index: index,
                expiryText: expiryText(for: entry.credit, timeZone: timeZone, locale: locale),
                isFirstExpiring: index == 0,
                urgency: urgency(for: entry.date, now: now)
            )
        }
    }

    private static func urgency(for date: Date, now: Date) -> CodexResetCreditUrgency {
        let hoursUntilExpiry = date.timeIntervalSince(now) / 3_600
        if hoursUntilExpiry <= 24 {
            return .urgent
        }
        if hoursUntilExpiry <= 72 {
            return .soon
        }
        return .normal
    }

    private static func parseISO8601Date(_ value: String) -> Date? {
        let fractionalParser = ISO8601DateFormatter()
        fractionalParser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalParser.date(from: value) {
            return date
        }

        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime]
        return parser.date(from: value)
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [] }
        return stride(from: 0, to: count, by: size).map { start in
            Array(self[start..<Swift.min(start + size, count)])
        }
    }
}
