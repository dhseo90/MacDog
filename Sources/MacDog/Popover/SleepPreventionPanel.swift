import SwiftUI

struct SleepPreventionPanel: View {
    let sleepPreventionStatus: SleepPreventionStatus
    let sleepPreventionTriggerStatus: SleepPreventionTriggerStatus
    let onAction: (PetAction) -> Void
    let onPreferencesChanged: () -> Void

    @AppStorage(RunnerPreferences.sleepPreventionControlModeKey) private var sleepPreventionControlMode = RunnerPreferences.defaultSleepPreventionControlMode.rawValue
    @AppStorage(RunnerPreferences.sleepPreventionSessionPresetKey) private var sleepPreventionSessionPreset = RunnerPreferences.defaultSleepPreventionSessionPreset.rawValue
    @AppStorage(RunnerPreferences.sleepPreventionPowerAdapterTriggerKey) private var powerAdapterTriggerEnabled = false
    @AppStorage(RunnerPreferences.sleepPreventionCodexAppTriggerKey) private var codexAppTriggerEnabled = false
    @AppStorage(RunnerPreferences.sleepPreventionChargingBelowThresholdTriggerKey) private var chargingBelowThresholdTriggerEnabled = false
    @AppStorage(RunnerPreferences.sleepPreventionCPUThresholdTriggerKey) private var cpuThresholdTriggerEnabled = false
    @AppStorage(RunnerPreferences.sleepPreventionMemoryThresholdTriggerKey) private var memoryThresholdTriggerEnabled = false
    @AppStorage(RunnerPreferences.sleepPreventionNetworkActivityTriggerKey) private var networkActivityTriggerEnabled = false
    @AppStorage(RunnerPreferences.sleepPreventionExternalVolumeTriggerKey) private var externalVolumeTriggerEnabled = false
    @AppStorage(RunnerPreferences.sleepPreventionBatteryThresholdPercentKey) private var batteryThresholdPercent = RunnerPreferences.defaultSleepPreventionBatteryThresholdPercent
    @AppStorage(RunnerPreferences.sleepPreventionCPUThresholdPercentKey) private var cpuThresholdPercent = RunnerPreferences.defaultSleepPreventionCPUThresholdPercent
    @AppStorage(RunnerPreferences.sleepPreventionMemoryThresholdPercentKey) private var memoryThresholdPercent = RunnerPreferences.defaultSleepPreventionMemoryThresholdPercent
    @AppStorage(RunnerPreferences.sleepPreventionNetworkThresholdKBPerSecondKey) private var networkThresholdKBPerSecond = RunnerPreferences.defaultSleepPreventionNetworkThresholdKBPerSecond
    @AppStorage(RunnerPreferences.sleepPreventionAppMatchTextKey) private var appMatchText = RunnerPreferences.defaultSleepPreventionAppMatchText
    @AppStorage(RunnerPreferences.sleepPreventionPreventDisplaySleepKey) private var preventDisplaySleep = RunnerPreferences.defaultSleepPreventionPreventDisplaySleep
    @AppStorage(RunnerPreferences.sleepPreventionPreventClosedLidSleepKey) private var preventClosedLidSleep = RunnerPreferences.defaultSleepPreventionPreventClosedLidSleep
    @AppStorage(RunnerPreferences.sleepPreventionDisableScreenLockKey) private var disableScreenLock = RunnerPreferences.defaultSleepPreventionDisableScreenLock

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            PopoverFormSection(title: "제어 방식", systemImage: "power") {
                controlModeButtons

                Text(controlModeSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, currentControlMode == .condition ? 2 : 0)
            }

            if currentControlMode == .time {
                PopoverFormSection(title: "유지 시간", systemImage: "timer") {
                    sessionPresetButtons

                    Text("선택한 시간 동안 유지하고, 시간이 지나면 자동으로 꺼집니다.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let sleepPreventionErrorMessage {
                Text(sleepPreventionErrorMessage)
                    .font(.caption2)
                    .foregroundStyle(Color.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if currentControlMode == .condition {
                PopoverFormSection(title: "상태 기준", systemImage: "slider.horizontal.3") {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 14) {
                            triggerToggle("전원 연결", isOn: $powerAdapterTriggerEnabled)
                            triggerToggle("Codex 실행 중", isOn: $codexAppTriggerEnabled)
                        }
                        HStack(spacing: 14) {
                            triggerToggle("배터리 \(effectiveBatteryThresholdPercent)% 이상", isOn: $chargingBelowThresholdTriggerEnabled)
                            triggerToggle("CPU 사용량 \(effectiveCPUThresholdPercent)% 이상", isOn: $cpuThresholdTriggerEnabled)
                        }
                        HStack(spacing: 14) {
                            triggerToggle("메모리 사용량 \(effectiveMemoryThresholdPercent)% 이상", isOn: $memoryThresholdTriggerEnabled)
                            triggerToggle("네트워크 전송 중", isOn: $networkActivityTriggerEnabled)
                        }
                        HStack(spacing: 14) {
                            triggerToggle("외장/공유 드라이브 연결", isOn: $externalVolumeTriggerEnabled)
                            Spacer(minLength: 0)
                        }
                    }

                    if showsThresholdSettings {
                        VStack(alignment: .leading, spacing: 5) {
                            if chargingBelowThresholdTriggerEnabled {
                                thresholdSlider(
                                    title: "배터리",
                                    valueText: "\(effectiveBatteryThresholdPercent)%",
                                    value: batteryThresholdBinding,
                                    range: Double(RunnerPreferences.minimumSleepPreventionBatteryThresholdPercent)...Double(RunnerPreferences.maximumSleepPreventionBatteryThresholdPercent),
                                    step: 5
                                )
                            }
                            if cpuThresholdTriggerEnabled {
                                thresholdSlider(
                                    title: "CPU",
                                    valueText: "\(effectiveCPUThresholdPercent)%",
                                    value: cpuThresholdBinding,
                                    range: Double(RunnerPreferences.minimumSleepPreventionCPUThresholdPercent)...Double(RunnerPreferences.maximumSleepPreventionCPUThresholdPercent),
                                    step: 5
                                )
                            }
                            if memoryThresholdTriggerEnabled {
                                thresholdSlider(
                                    title: "메모리",
                                    valueText: "\(effectiveMemoryThresholdPercent)%",
                                    value: memoryThresholdBinding,
                                    range: Double(RunnerPreferences.minimumSleepPreventionMemoryThresholdPercent)...Double(RunnerPreferences.maximumSleepPreventionMemoryThresholdPercent),
                                    step: 5
                                )
                            }
                        }
                        .padding(.top, 1)
                    }
                }
            }

            if currentControlMode != .off {
                Divider()

                PopoverFormSection(title: "보호 옵션", systemImage: "display") {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 14) {
                            triggerToggle("화면 잠자기 방지", isOn: $preventDisplaySleep)
                            triggerToggle("덮개 닫힘 보호", isOn: $preventClosedLidSleep)
                        }

                        if preventClosedLidSleep, let warning = sleepPreventionStatus.closedLidWarningMessage {
                            protectionWarningButton(
                                "덮개 닫힘 보호 확인 · \(warning)",
                                systemImage: "wrench.and.screwdriver",
                                action: .installPrivilegedHelper
                            )
                        }

                        triggerToggle("보호기 후 암호 요구 해제", isOn: $disableScreenLock)

                        if disableScreenLock, let warning = sleepPreventionStatus.screenLockWarningMessage {
                            protectionWarningButton(
                                "잠금 화면 설정 열기 · \(warning)",
                                systemImage: "lock.open",
                                action: .openLockScreenSettings
                            )
                        }
                    }
                }
            }
        }
        .onChange(of: powerAdapterTriggerEnabled) { _, enabled in
            RunnerPreferences.setSleepPreventionPowerAdapterTrigger(enabled)
            deferredPreferencesChanged()
        }
        .onChange(of: codexAppTriggerEnabled) { _, enabled in
            if enabled {
                RunnerPreferences.setSleepPreventionAppMatchText(RunnerPreferences.defaultSleepPreventionAppMatchText)
                appMatchText = RunnerPreferences.defaultSleepPreventionAppMatchText
            }
            RunnerPreferences.setSleepPreventionCodexAppTrigger(enabled)
            deferredPreferencesChanged()
        }
        .onChange(of: chargingBelowThresholdTriggerEnabled) { _, enabled in
            RunnerPreferences.setSleepPreventionChargingBelowThresholdTrigger(enabled)
            deferredPreferencesChanged()
        }
        .onChange(of: cpuThresholdTriggerEnabled) { _, enabled in
            RunnerPreferences.setSleepPreventionCPUThresholdTrigger(enabled)
            deferredPreferencesChanged()
        }
        .onChange(of: memoryThresholdTriggerEnabled) { _, enabled in
            RunnerPreferences.setSleepPreventionMemoryThresholdTrigger(enabled)
            deferredPreferencesChanged()
        }
        .onChange(of: networkActivityTriggerEnabled) { _, enabled in
            RunnerPreferences.setSleepPreventionNetworkActivityTrigger(enabled)
            networkThresholdKBPerSecond = RunnerPreferences.defaultSleepPreventionNetworkThresholdKBPerSecond
            deferredPreferencesChanged()
        }
        .onChange(of: externalVolumeTriggerEnabled) { _, enabled in
            RunnerPreferences.setSleepPreventionExternalVolumeTrigger(enabled)
            deferredPreferencesChanged()
        }
        .onChange(of: preventDisplaySleep) { _, enabled in
            RunnerPreferences.setSleepPreventionPreventDisplaySleep(enabled)
            deferredPreferencesChanged()
        }
        .onChange(of: preventClosedLidSleep) { _, enabled in
            RunnerPreferences.setSleepPreventionPreventClosedLidSleep(enabled)
            deferredPreferencesChanged()
        }
        .onChange(of: disableScreenLock) { _, enabled in
            RunnerPreferences.setSleepPreventionDisableScreenLock(enabled)
            deferredPreferencesChanged()
        }
    }

    private var controlModeButtons: some View {
        HStack(spacing: 4) {
            ForEach(SleepPreventionControlMode.allCases) { mode in
                segmentButton(
                    title: mode.label,
                    isSelected: currentControlMode == mode
                ) {
                    selectControlMode(mode)
                }
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        )
    }

    private var sessionPresetButtons: some View {
        HStack(spacing: 4) {
            ForEach(SleepPreventionSessionPreset.allCases) { preset in
                segmentButton(
                    title: preset.label,
                    isSelected: currentSessionPreset == preset
                ) {
                    selectSessionPreset(preset)
                }
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        )
    }

    private func segmentButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(isSelected ? .semibold : .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, minHeight: 28)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isSelected ? Color.accentColor : Color.clear)
                )
                .contentShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private var currentControlMode: SleepPreventionControlMode {
        SleepPreventionControlMode(rawValue: sleepPreventionControlMode) ?? RunnerPreferences.defaultSleepPreventionControlMode
    }

    private var currentSessionPreset: SleepPreventionSessionPreset {
        SleepPreventionSessionPreset(rawValue: sleepPreventionSessionPreset) ?? RunnerPreferences.defaultSleepPreventionSessionPreset
    }

    private var effectiveBatteryThresholdPercent: Int {
        RunnerPreferences.normalizedSleepPreventionBatteryThresholdPercent(batteryThresholdPercent)
    }

    private var effectiveCPUThresholdPercent: Int {
        RunnerPreferences.normalizedSleepPreventionCPUThresholdPercent(cpuThresholdPercent)
    }

    private var effectiveMemoryThresholdPercent: Int {
        RunnerPreferences.normalizedSleepPreventionMemoryThresholdPercent(memoryThresholdPercent)
    }

    private var showsThresholdSettings: Bool {
        chargingBelowThresholdTriggerEnabled || cpuThresholdTriggerEnabled || memoryThresholdTriggerEnabled
    }

    private var controlModeSummary: String {
        switch currentControlMode {
        case .off:
            return "꺼짐"
        case .time:
            return sleepPreventionStatus.summary
        case .condition:
            if sleepPreventionTriggerStatus.isMatched {
                return sleepPreventionTriggerStatus.summary
            }
            return "대기 중 · 기준을 선택하세요"
        }
    }

    private var sleepPreventionErrorMessage: String? {
        guard let errorMessage = sleepPreventionStatus.errorMessage else { return nil }
        return "잠자기 방지 오류 · \(errorMessage)"
    }

    private func selectControlMode(_ mode: SleepPreventionControlMode) {
        sleepPreventionControlMode = mode.rawValue
        RunnerPreferences.setSleepPreventionControlMode(mode)
        deferredPreferencesChanged()
    }

    private func selectSessionPreset(_ preset: SleepPreventionSessionPreset) {
        sleepPreventionSessionPreset = preset.rawValue
        RunnerPreferences.setSleepPreventionSessionPreset(preset)
        deferredPreferencesChanged()
    }

    private func deferredPreferencesChanged() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            onPreferencesChanged()
        }
    }

    private var batteryThresholdBinding: Binding<Double> {
        Binding(
            get: { Double(effectiveBatteryThresholdPercent) },
            set: { newValue in
                let value = RunnerPreferences.normalizedSleepPreventionBatteryThresholdPercent(Int(newValue.rounded()))
                RunnerPreferences.setSleepPreventionBatteryThresholdPercent(value)
                batteryThresholdPercent = value
                deferredPreferencesChanged()
            }
        )
    }

    private var cpuThresholdBinding: Binding<Double> {
        Binding(
            get: { Double(effectiveCPUThresholdPercent) },
            set: { newValue in
                let value = RunnerPreferences.normalizedSleepPreventionCPUThresholdPercent(Int(newValue.rounded()))
                RunnerPreferences.setSleepPreventionCPUThresholdPercent(value)
                cpuThresholdPercent = value
                deferredPreferencesChanged()
            }
        )
    }

    private var memoryThresholdBinding: Binding<Double> {
        Binding(
            get: { Double(effectiveMemoryThresholdPercent) },
            set: { newValue in
                let value = RunnerPreferences.normalizedSleepPreventionMemoryThresholdPercent(Int(newValue.rounded()))
                RunnerPreferences.setSleepPreventionMemoryThresholdPercent(value)
                memoryThresholdPercent = value
                deferredPreferencesChanged()
            }
        )
    }

    private func triggerToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .toggleStyle(.checkbox)
            .controlSize(.small)
            .font(.caption2.weight(.medium))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func thresholdSlider(
        title: String,
        valueText: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 44, alignment: .leading)
            Slider(value: value, in: range, step: step)
                .controlSize(.mini)
            Text(valueText)
                .font(.caption2.monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .frame(width: 38, alignment: .trailing)
        }
        .frame(height: 18)
    }

    private func protectionWarningButton(_ title: String, systemImage: String, action: PetAction) -> some View {
        Button {
            onAction(action)
        } label: {
            Label(title, systemImage: systemImage)
                .font(.caption2)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}
