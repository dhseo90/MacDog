import CodexUsageCore
import SwiftUI

struct CodexRecoveryPlannerBlock: View {
    let schedule: CodexUsageResetSchedule
    let plan: CodexUsageSessionPlan
    let selectedDuration: Binding<CodexUsageSessionPlanDuration>

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            CodexRecoveryCardsBlock(schedule: schedule)
            CodexSessionPlanBlock(plan: plan, selectedDuration: selectedDuration)
        }
    }
}

private struct CodexRecoveryCardsBlock: View {
    let schedule: CodexUsageResetSchedule

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("회복 일정")
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 6)
                Label(schedule.trustSummary, systemImage: trustSystemImage)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(trustTint)

            if schedule.primaryEntries.isEmpty {
                CodexRecoveryPlaceholderCard(
                    title: schedule.summaryText,
                    detail: schedule.trustSummary,
                    tint: trustTint,
                    systemImage: trustSystemImage
                )
            } else {
                HStack(spacing: 6) {
                    ForEach(schedule.primaryEntries) { entry in
                        CodexRecoveryCard(entry: entry, scheduleTint: trustTint)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var trustTint: Color {
        switch schedule.state {
        case .ok:
            .secondary
        case .waiting:
            .secondary
        case .stale:
            .orange
        case .error, .protocolDrift:
            .red
        }
    }

    private var trustSystemImage: String {
        switch schedule.state {
        case .ok:
            "checkmark.circle.fill"
        case .waiting:
            "hourglass"
        case .stale:
            "clock.badge.exclamationmark"
        case .error:
            "exclamationmark.triangle.fill"
        case .protocolDrift:
            "rectangle.badge.exclamationmark"
        }
    }
}

private struct CodexRecoveryCard: View {
    let entry: CodexUsageResetScheduleEntry
    let scheduleTint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.semibold))
                    .frame(width: 12)
                Text(entry.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
            }

            Text(relativeTimeText)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text("남음 \(percentText(entry.remainingPercent)) · 사용 \(percentText(entry.usedPercent))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .padding(.horizontal, 7)
        .foregroundStyle(tint)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(tint.opacity(entry.isNextRecovery ? 0.13 : 0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(tint.opacity(entry.isNextRecovery ? 0.34 : 0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.title), \(relativeTimeText), \(entry.remainingPercent.rounded())% 남음")
    }

    private var tint: Color {
        entry.isNextRecovery ? .accentColor : scheduleTint
    }

    private var systemImage: String {
        entry.isNextRecovery ? "arrow.clockwise.circle.fill" : "clock"
    }

    private var relativeTimeText: String {
        guard let seconds = entry.remainingSeconds else { return "시각 확인 불가" }
        if seconds <= 0 { return "곧 회복" }

        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60

        if days > 0 {
            return hours > 0 ? "\(days)일 \(hours)시간 후" : "\(days)일 후"
        }
        if hours > 0 {
            return minutes > 0 ? "\(hours)시간 \(minutes)분 후" : "\(hours)시간 후"
        }
        return "\(max(minutes, 1))분 후"
    }

    private func percentText(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value))%"
        }
        return "\(String(format: "%.1f", value))%"
    }
}

private struct CodexRecoveryPlaceholderCard: View {
    let title: String
    let detail: String
    let tint: Color
    let systemImage: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.semibold))
                .frame(width: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 7)
        .foregroundStyle(tint)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(tint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct CodexSessionPlanBlock: View {
    let plan: CodexUsageSessionPlan
    let selectedDuration: Binding<CodexUsageSessionPlanDuration>

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Picker("", selection: selectedDuration) {
                ForEach(CodexUsageSessionPlanDuration.allCases) { duration in
                    Text(duration.label).tag(duration)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.mini)
            .labelsHidden()

            HStack(alignment: .top, spacing: 7) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .frame(width: 14)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(plan.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)

                        if let durationSummary {
                            Text(durationSummary)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                    }

                    Text(plan.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 0)
            }
            .foregroundStyle(tint)
            .padding(.vertical, 6)
            .padding(.horizontal, 7)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(tint.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(tint.opacity(0.22), lineWidth: 1)
            )
        }
        .accessibilityElement(children: .contain)
    }

    private var tint: Color {
        switch plan.state {
        case .safe:
            .green
        case .watch:
            .orange
        case .risky:
            .red
        case .unavailable:
            .secondary
        }
    }

    private var systemImage: String {
        switch plan.state {
        case .safe:
            "checkmark.circle.fill"
        case .watch:
            "exclamationmark.triangle.fill"
        case .risky:
            "exclamationmark.octagon.fill"
        case .unavailable:
            "chart.line.uptrend.xyaxis"
        }
    }

    private var durationSummary: String? {
        guard let seconds = plan.durationSeconds else { return nil }
        if seconds <= 0 { return "곧 종료" }

        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        if hours > 0, minutes > 0 {
            return "\(hours)시간 \(minutes)분"
        }
        if hours > 0 {
            return "\(hours)시간"
        }
        return "\(max(minutes, 1))분"
    }
}
