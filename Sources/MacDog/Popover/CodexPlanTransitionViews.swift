import CodexUsageCore
import SwiftUI

enum CodexPlanTransitionSettingsPersistence {
    static func targetEpochID(
        previousConfiguration: CodexPlanTransitionConfiguration?,
        confirmedAt: Int?,
        makeID: () -> String = { UUID().uuidString }
    ) -> String {
        guard let previousConfiguration else { return makeID() }
        if previousConfiguration.confirmedTransitionAt == nil, confirmedAt != nil {
            return makeID()
        }
        return previousConfiguration.targetPlanEpochID
    }

    @discardableResult
    static func save(
        _ configuration: CodexPlanTransitionConfiguration,
        replacing _: CodexPlanTransitionConfiguration?,
        configurationStore: CodexPlanTransitionConfigurationStore = .init(),
        historyStore: CodexUsageFiveHourHistoryStore = .init()
    ) throws -> Int {
        try configurationStore.write(configuration)
        return try reconcile(configuration, historyStore: historyStore)
    }

    @discardableResult
    static func reconcile(
        _ configuration: CodexPlanTransitionConfiguration,
        historyStore: CodexUsageFiveHourHistoryStore = .init()
    ) throws -> Int {
        guard let confirmedAt = configuration.confirmedTransitionAt else { return 0 }
        return try historyStore.reassignPlanEpoch(
            forWindowsStartingAtOrAfter: confirmedAt,
            from: configuration.currentPlanEpochID,
            to: configuration.targetPlanEpochID
        )
    }
}

struct CodexPlanTransitionReadinessBlock: View {
    let configuration: CodexPlanTransitionConfiguration?
    let configurationError: String?
    let scenario: CodexPlanTransitionScenario?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text("플랜 전환 준비")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize()
            Text(compactDetailText)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
            Spacer(minLength: 2)
            Text(statusText)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(statusColor)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.accentColor.opacity(0.055))
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("codex-plan-transition-readiness")
        .accessibilityLabel("플랜 전환 준비, \(detailText), \(statusText)")
    }

    private var statusText: String {
        if configurationError != nil { return "설정 오류" }
        guard let scenario else { return "설정 필요" }
        switch scenario.transitionStatus {
        case .observing:
            return "전환 관측 중"
        case .completed:
            return "전환 관측 완료"
        case .awaitingObservations:
            return "전환 관측 부족"
        case .planned(let at):
            return "예정 \(Self.shortDate(at))"
        case .notScheduled:
            return scenario.observationStatus == .sufficient ? "시나리오 준비" : "관측 부족"
        }
    }

    private var detailText: String {
        if let configurationError { return configurationError }
        guard let configuration, let scenario else {
            return "설정 탭에서 현재·목표 플랜과 상대 용량을 입력하세요."
        }
        if let actualP90 = scenario.targetFiveHour.observedP90Percent,
           let projectedP90 = scenario.fiveHour.projectedP90Percent,
           let delta = scenario.fiveHourP90DeltaPercent {
            return "전환 후 실제 P90 \(Self.percent(actualP90))% · 예상 \(Self.percent(projectedP90))% · 차이 \(Self.signedPercent(delta))%"
        }
        switch scenario.transitionStatus {
        case .observing, .awaitingObservations:
            return "전환 후 5시간 \(scenario.targetFiveHour.observationCount) window · 실제 관측 수집 중"
        case .notScheduled, .planned, .completed:
            break
        }
        guard scenario.observationStatus == .sufficient,
              let observedP90 = scenario.fiveHour.observedP90Percent,
              let projectedP90 = scenario.fiveHour.projectedP90Percent
        else {
            return "\(configuration.targetPlanLabel) · 5시간 \(scenario.fiveHour.observationCount) window · 수치 확정 전"
        }
        let weekly = scenario.weekly.projectedP90Percent.map {
            " · 주간 예상 P90 \(Self.percent($0))%"
        } ?? ""
        return "공식 5시간 P90 \(Self.percent(observedP90))% → 예상 \(Self.percent(projectedP90))%\(weekly) · 초과 \(scenario.fiveHour.limitExceededWindowCount)"
    }

    private var compactDetailText: String {
        if configurationError != nil { return "설정 파일 복구 필요" }
        guard configuration != nil else { return "설정 탭에서 조건 입력" }
        guard let scenario else { return "사용자 설정 기반 예상" }
        if let actualP90 = scenario.targetFiveHour.observedP90Percent,
           let delta = scenario.fiveHourP90DeltaPercent {
            return "실제 P90 \(Self.percent(actualP90))% · 예상 대비 \(Self.signedPercent(delta))%"
        }
        switch scenario.transitionStatus {
        case .observing, .awaitingObservations:
            return "전환 후 실제 \(scenario.targetFiveHour.observationCount) window"
        case .notScheduled, .planned, .completed:
            break
        }
        guard scenario.observationStatus == .sufficient,
              let projectedP90 = scenario.fiveHour.projectedP90Percent
        else {
            return "사용자 설정 기반 예상 · 5시간 \(scenario.fiveHour.observationCount) window"
        }
        return "사용자 설정 기반 예상 P90 \(Self.percent(projectedP90))%"
    }

    private var statusColor: Color {
        guard let scenario else { return .secondary }
        if scenario.fiveHour.limitExceededWindowCount > 0 { return .red }
        return scenario.observationStatus == .sufficient ? .green : .orange
    }

    private static func percent(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }

    private static func signedPercent(_ value: Double) -> String {
        value.formatted(
            .number.sign(strategy: .always()).precision(.fractionLength(0...1))
        )
    }

    private static func shortDate(_ timestamp: Int) -> String {
        Date(timeIntervalSince1970: TimeInterval(timestamp)).formatted(
            .dateTime.month().day()
        )
    }
}

struct CodexPlanTransitionSettingsEditor: View {
    let initialConfiguration: CodexPlanTransitionConfiguration?
    let configurationError: String?
    let onSaved: () -> Void

    @State private var currentPlanLabel: String
    @State private var targetPlanLabel: String
    @State private var targetRelativeCapacityPercent: Double
    @State private var reservePercent: Double
    @State private var hasPlannedTransition: Bool
    @State private var plannedTransitionDate: Date
    @State private var transitionConfirmed: Bool
    @State private var confirmedTransitionDate: Date
    @State private var saveMessage: String?
    @State private var saveFailed = false

    init(
        configuration: CodexPlanTransitionConfiguration?,
        configurationError: String? = nil,
        onSaved: @escaping () -> Void
    ) {
        self.initialConfiguration = configuration
        self.configurationError = configurationError
        self.onSaved = onSaved
        let now = Date()
        _currentPlanLabel = State(initialValue: configuration?.currentPlanLabel ?? "")
        _targetPlanLabel = State(initialValue: configuration?.targetPlanLabel ?? "")
        _targetRelativeCapacityPercent = State(
            initialValue: (configuration?.targetRelativeCapacity ?? 0.5) * 100
        )
        _reservePercent = State(initialValue: configuration?.reservePercent ?? 20)
        _hasPlannedTransition = State(initialValue: configuration?.plannedTransitionAt != nil)
        _plannedTransitionDate = State(
            initialValue: configuration?.plannedTransitionAt.map {
                Date(timeIntervalSince1970: TimeInterval($0))
            } ?? now.addingTimeInterval(7 * 24 * 60 * 60)
        )
        _transitionConfirmed = State(initialValue: configuration?.confirmedTransitionAt != nil)
        _confirmedTransitionDate = State(
            initialValue: configuration?.confirmedTransitionAt.map {
                Date(timeIntervalSince1970: TimeInterval($0))
            } ?? now
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let configurationError {
                Text(configurationError)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 6) {
                TextField("현재 플랜", text: $currentPlanLabel)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("현재 플랜 label")
                TextField("목표 플랜", text: $targetPlanLabel)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("목표 플랜 label")
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("상대 용량")
                TextField("50", value: $targetRelativeCapacityPercent, format: .number)
                    .frame(width: 46)
                    .textFieldStyle(.roundedBorder)
                Text("%")
                Spacer(minLength: 4)
                Text("reserve")
                TextField("20", value: $reservePercent, format: .number)
                    .frame(width: 42)
                    .textFieldStyle(.roundedBorder)
                Text("%")
            }
            .font(.caption2)

            Toggle("전환 예정일", isOn: $hasPlannedTransition)
                .toggleStyle(.checkbox)
                .controlSize(.small)
            if hasPlannedTransition {
                DatePicker(
                    "예정",
                    selection: $plannedTransitionDate,
                    displayedComponents: [.date]
                )
                .controlSize(.small)
                .font(.caption2)
            }

            Toggle("실제 전환 확인", isOn: $transitionConfirmed)
                .toggleStyle(.checkbox)
                .controlSize(.small)
                .disabled(initialConfiguration?.confirmedTransitionAt != nil)
            if transitionConfirmed {
                DatePicker(
                    "확인 시각",
                    selection: $confirmedTransitionDate,
                    in: ...Date(),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .controlSize(.small)
                .font(.caption2)
                .disabled(initialConfiguration?.confirmedTransitionAt != nil)
            }

            HStack(spacing: 6) {
                Button("플랜 설정 저장") {
                    save()
                }
                .controlSize(.small)
                .disabled(configurationError != nil)
                Spacer(minLength: 4)
                if let saveMessage {
                    Text(saveMessage)
                        .font(.caption2)
                        .foregroundStyle(saveFailed ? Color.red : Color.green)
                        .lineLimit(1)
                }
            }
        }
        .font(.caption2)
    }

    private func save() {
        do {
            let confirmedAt = initialConfiguration?.confirmedTransitionAt ?? (
                transitionConfirmed ? Int(confirmedTransitionDate.timeIntervalSince1970) : nil
            )
            if let confirmedAt, confirmedAt > Int(Date().timeIntervalSince1970) {
                throw CodexPlanTransitionConfigurationError.invalidTransitionTimestamp
            }
            let targetEpochID = CodexPlanTransitionSettingsPersistence.targetEpochID(
                previousConfiguration: initialConfiguration,
                confirmedAt: confirmedAt
            )
            let configuration = try CodexPlanTransitionConfiguration(
                currentPlanLabel: currentPlanLabel,
                targetPlanLabel: targetPlanLabel,
                targetRelativeCapacity: targetRelativeCapacityPercent / 100,
                reservePercent: reservePercent,
                plannedTransitionAt: hasPlannedTransition
                    ? Int(plannedTransitionDate.timeIntervalSince1970)
                    : nil,
                confirmedTransitionAt: confirmedAt,
                currentPlanEpochID: initialConfiguration?.currentPlanEpochID ??
                    CodexUsageFiveHourHistorySample.legacyPlanEpochID,
                targetPlanEpochID: targetEpochID
            )
            try CodexPlanTransitionSettingsPersistence.save(
                configuration,
                replacing: initialConfiguration
            )
            saveFailed = false
            saveMessage = "저장됨"
            onSaved()
        } catch {
            saveFailed = true
            saveMessage = error.localizedDescription
        }
    }
}
