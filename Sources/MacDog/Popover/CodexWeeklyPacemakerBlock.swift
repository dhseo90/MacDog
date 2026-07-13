import CodexUsageCore
import SwiftUI

struct CodexWeeklyPacemakerBlock: View {
    let pacemaker: CodexWeeklyPacemaker?
    let fiveHourPace: CodexUsagePaceProjection?

    var body: some View {
        Text(titlePrefix + pacemakerSummary + fiveHourPaceSuffix)
            .font(.caption2.monospacedDigit().weight(.medium))
            .foregroundStyle(pacemaker.map(paceTint) ?? .secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.62)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("codex-weekly-pacemaker")
    }

    private var titlePrefix: String {
        pacemaker.map { "주간 페이스 Day \($0.dayIndex)/7 · " } ?? "주간 페이스 · "
    }

    private var fiveHourPaceSuffix: String {
        fiveHourPace.map { " · " + fiveHourPaceText($0) } ?? ""
    }

    private var pacemakerSummary: String {
        guard let pacemaker else {
            return "주간 사용량과 reset 정보 대기"
        }
        guard let dayUsed = pacemaker.currentDayUsedPercent,
              let dayRemaining = pacemaker.remainingDailyTargetPercent else {
            return "오늘 기준 계산 중 · 누적 \(percent(pacemaker.currentUsedPercent))% / " +
                "목표 \(percent(pacemaker.cumulativeTargetUsedPercent))%"
        }
        return "오늘 \(percent(dayUsed))% / \(percent(CodexWeeklyPacemaker.dailyTargetUsedPercent))%" +
            " · 여유 \(percent(dayRemaining))% · 누적 \(percent(pacemaker.currentUsedPercent))% / " +
            "\(percent(pacemaker.cumulativeTargetUsedPercent))%"
    }

    private func paceTint(_ pacemaker: CodexWeeklyPacemaker) -> Color {
        if pacemaker.isDailyTargetExceeded || pacemaker.isCumulativeTargetExceeded {
            return .orange
        }
        return pacemaker.isDailyTargetApproaching ? .yellow : .secondary
    }

    private func fiveHourPaceText(_ projection: CodexUsagePaceProjection) -> String {
        switch projection.state {
        case .projected:
            guard let rate = projection.usedPercentPerHour,
                  let projected = projection.projectedFinalUsedPercent else {
                return "5h pace 계산 중"
            }
            return "5h pace \(percent(rate))%/h → \(percent(projected))%"
        case .waitingForSamples:
            return "5h pace sample 대기"
        case .stale:
            return "5h pace stale"
        case .error:
            return "5h pace error"
        case .unavailable:
            return "5h pace 계산 중"
        }
    }

    private func percent(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}
