import CodexUsageCore
import Foundation
import SwiftUI

struct CodexResetCreditsBlock: View {
    let resetCredits: RateLimitResetCreditsSummary?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("초기화권")
                .font(.caption.weight(.semibold))
            Text(CodexResetCreditTextFormatter.countText(for: resetCredits))
                .font(.caption.weight(.semibold))
            Text(detailText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.primary.opacity(0.16), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var detailText: String {
        guard let resetCredits else { return "정보 미확인" }
        if resetCredits.availableCount <= 0 {
            return "사용 가능한 초기화권 없음"
        }
        if resetCredits.credits.isEmpty {
            return "만료일 갱신 필요"
        }
        return CodexResetCreditTextFormatter.firstExpiryText(for: resetCredits)
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

    static func firstExpiryText(
        for summary: RateLimitResetCreditsSummary?,
        timeZone: TimeZone = .current,
        locale: Locale = .current
    ) -> String {
        guard let summary else { return "정보 미확인" }
        if summary.availableCount <= 0 {
            return "사용 가능한 초기화권 없음"
        }
        guard let first = displayItems(for: summary, timeZone: timeZone, locale: locale).first else {
            return "만료일 갱신 필요"
        }
        return "먼저 \(first.expiryText)"
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
