import CodexUsageCore
import SwiftUI

struct UsagePopoverView: View {
    let state: UsageMonitorState
    let onPreferencesChanged: () -> Void
    let onAction: (PetAction) -> Void

    @AppStorage("macDogPopoverModule") private var selectedModuleRaw = MacDogPopoverModule.codex.rawValue

    init(
        state: UsageMonitorState,
        onPreferencesChanged: @escaping () -> Void = {},
        onAction: @escaping (PetAction) -> Void = { _ in }
    ) {
        self.state = state
        self.onPreferencesChanged = onPreferencesChanged
        self.onAction = onAction
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                header
                modulePicker
            }

            Divider()

            switch selectedModule {
            case .codex:
                codexUsageContent
            case .mac:
                SystemMetricsPanel(
                    snapshot: state.systemMetrics,
                    sleepPreventionStatus: state.sleepPreventionStatus,
                    sleepPreventionTriggerStatus: state.sleepPreventionTriggerStatus,
                    onPreferencesChanged: onPreferencesChanged,
                    onAction: onAction
                )
            }

            RunnerControls(onChange: onPreferencesChanged)
        }
        .padding(16)
        .frame(width: 280, alignment: .leading)
    }

    private var selectedModule: MacDogPopoverModule {
        MacDogPopoverModule(rawValue: selectedModuleRaw) ?? .codex
    }

    private var modulePicker: some View {
        Picker("모듈", selection: $selectedModuleRaw) {
            ForEach(MacDogPopoverModule.allCases) { module in
                Text(module.shortLabel).tag(module.rawValue)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .frame(width: 112)
    }

    @ViewBuilder
    private var codexUsageContent: some View {
        if let limit = state.codexLimit {
            if let message = state.highUsageMessage {
                PressureBanner(message: message, phase: state.phase)
            }

            VStack(alignment: .leading, spacing: 10) {
                UsageRow(title: "5시간", window: limit.fiveHour)
                UsageRow(title: "주간", window: limit.weekly)
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                metadataRow("플랜", limit.planType ?? "알 수 없음")
                metadataRow("크레딧", limit.credits?.balance ?? "알 수 없음")
                metadataRow("소스", state.sourceLabel)
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
        }

        if let error = state.errorMessage, !state.isRefreshing {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(2)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(phaseColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text("코덱스 사용량")
                    .font(.headline)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
    }

    private var statusText: String {
        guard let status = state.selectedWindowStatus else {
            return state.phase.statusLabel
        }
        return "\(state.phase.statusLabel) · \(status.summary)"
    }

    private var phaseColor: Color {
        switch state.phase {
        case .calm:
            .secondary
        case .active:
            .accentColor
        case .fast:
            .orange
        case .sprint, .limit:
            .red
        }
    }

    private func metadataRow(_ key: String, _ value: String) -> some View {
        GridRow {
            Text(key)
                .foregroundStyle(.secondary)
            Text(value)
                .lineLimit(1)
        }
        .font(.caption)
    }
}

private enum MacDogPopoverModule: String, CaseIterable, Identifiable {
    case codex
    case mac

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .codex:
            "Codex"
        case .mac:
            "Mac"
        }
    }
}

private struct SystemMetricsPanel: View {
    let snapshot: SystemMetricsSnapshot
    let sleepPreventionStatus: SleepPreventionStatus
    let sleepPreventionTriggerStatus: SleepPreventionTriggerStatus
    let onPreferencesChanged: () -> Void
    let onAction: (PetAction) -> Void

    @AppStorage(RunnerPreferences.sleepPreventionEnabledKey) private var sleepPreventionEnabled = false
    @AppStorage(RunnerPreferences.sleepPreventionSessionPresetKey) private var sleepPreventionSessionPreset = RunnerPreferences.defaultSleepPreventionSessionPreset.rawValue
    @AppStorage(RunnerPreferences.sleepPreventionPowerAdapterTriggerKey) private var powerAdapterTriggerEnabled = false
    @AppStorage(RunnerPreferences.sleepPreventionCodexAppTriggerKey) private var codexAppTriggerEnabled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Mac 상태", systemImage: "desktopcomputer")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("인터페이스 \(snapshot.activeInterfaceCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 5) {
                metricRow("CPU", snapshot.cpuSummary)
                metricRow("메모리", snapshot.memorySummary)
                metricRow("디스크", snapshot.diskSummary)
                metricRow("네트워크", snapshot.networkSummary)
                metricRow("배터리", snapshot.battery.summary)
                metricRow("전원", snapshot.battery.powerSummary)
                metricRow("충전 한도", snapshot.chargeLimitSupport.summary)
                metricRow("잠자기 방지", sleepPreventionStatus.summary)
                metricRow("방지 모드", currentSleepPreventionMode.label)
                metricRow("자동 조건", sleepPreventionTriggerStatus.summary)
            }

            controlLabel("잠자기 방지")
            Picker("잠자기 방지", selection: sleepPreventionModeBinding) {
                ForEach(SleepPreventionMode.allCases) { mode in
                    Text(mode.label).tag(mode.rawValue)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)

            if currentSleepPreventionMode == .timed {
                Picker("시간 기준 길이", selection: $sleepPreventionSessionPreset) {
                    ForEach(SleepPreventionSessionPreset.timedCases) { preset in
                        Text(preset.label).tag(preset.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            Button {
                onAction(.openBatterySettings)
            } label: {
                Label(batterySettingsLabel, systemImage: "battery.100percent")
            }
            .font(.caption)
            .buttonStyle(.borderless)
        }
        .onChange(of: sleepPreventionEnabled) { _, enabled in
            RunnerPreferences.setSleepPreventionEnabled(enabled)
            onPreferencesChanged()
        }
        .onChange(of: sleepPreventionSessionPreset) { _, rawValue in
            guard let preset = SleepPreventionSessionPreset(rawValue: rawValue) else { return }
            RunnerPreferences.setSleepPreventionSessionPreset(preset)
            onPreferencesChanged()
        }
        .onChange(of: powerAdapterTriggerEnabled) { _, enabled in
            RunnerPreferences.setSleepPreventionPowerAdapterTrigger(enabled)
            onPreferencesChanged()
        }
        .onChange(of: codexAppTriggerEnabled) { _, enabled in
            RunnerPreferences.setSleepPreventionCodexAppTrigger(enabled)
            onPreferencesChanged()
        }
    }

    private func metricRow(_ key: String, _ value: String) -> some View {
        GridRow {
            Text(key)
                .foregroundStyle(.secondary)
            Text(value)
                .lineLimit(1)
        }
        .font(.caption)
    }

    private var batterySettingsLabel: String {
        snapshot.chargeLimitSupport.isNativeChargeLimitAvailable ? "충전 한도 설정 열기" : "배터리 설정 열기"
    }

    private var currentSleepPreventionMode: SleepPreventionMode {
        RunnerPreferences().sleepPreventionMode
    }

    private var sleepPreventionModeBinding: Binding<String> {
        Binding(
            get: { currentSleepPreventionMode.rawValue },
            set: { rawValue in
                guard let mode = SleepPreventionMode(rawValue: rawValue) else { return }
                RunnerPreferences.setSleepPreventionMode(mode)
                onPreferencesChanged()
            }
        )
    }

    private func controlLabel(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

private struct PressureBanner: View {
    let message: String
    let phase: UsagePressurePhase

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: phase == .limit ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                .font(.caption)
            Text(message)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(tint)
        .padding(.vertical, 7)
        .padding(.horizontal, 9)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(tint.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(tint.opacity(0.24), lineWidth: 1)
        )
    }

    private var tint: Color {
        switch phase {
        case .calm:
            .secondary
        case .active:
            .accentColor
        case .fast:
            .orange
        case .sprint, .limit:
            .red
        }
    }
}

private struct RunnerControls: View {
    let onChange: () -> Void

    @AppStorage(RunnerPreferences.displayBasisKey) private var displayBasis = RunnerPreferences.defaultDisplayBasis.rawValue
    @AppStorage(RunnerPreferences.reducedMotionKey) private var reducedMotion = false
    @AppStorage(RunnerPreferences.animationPausedKey) private var animationPaused = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            controlLabel("러너 속도")
            Picker("러너 속도", selection: $displayBasis) {
                ForEach(UsageDisplayBasis.allCases) { basis in
                    Text(basis.label).tag(basis.rawValue)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .help("러너 속도를 조절할 사용량 기준을 선택합니다.")

            Toggle("움직임 줄이기", isOn: $reducedMotion)
                .font(.caption)

            Toggle("애니메이션 일시 정지", isOn: $animationPaused)
                .font(.caption)
        }
        .onChange(of: displayBasis) { _, _ in onChange() }
        .onChange(of: reducedMotion) { _, _ in onChange() }
        .onChange(of: animationPaused) { _, _ in onChange() }
    }

    private func controlLabel(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

private struct UsageRow: View {
    let title: String
    let window: UsageWindowReport?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progressValue)
                .tint(tint)

            Text(resetText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var summary: String {
        guard let window else { return "확인 불가" }
        return "\(UsageMonitorState.percent(window.usedPercent))% 사용 / \(UsageMonitorState.percent(window.remainingPercent))% 남음"
    }

    private var progressValue: Double {
        min(max((window?.usedPercent ?? 0) / 100, 0), 1)
    }

    private var resetText: String {
        guard let resetsAt = window?.resetsAt else { return "초기화 시각 알 수 없음" }
        let date = Date(timeIntervalSince1970: TimeInterval(resetsAt))
        return "초기화 \(date.formatted(date: .abbreviated, time: .shortened))"
    }

    private var tint: Color {
        switch window?.usedPercent ?? 0 {
        case 95...:
            .red
        case 80..<95:
            .orange
        case 50..<80:
            .accentColor
        default:
            .secondary
        }
    }
}
