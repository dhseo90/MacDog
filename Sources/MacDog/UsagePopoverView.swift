import AppKit
import CodexUsageCore
import MacDogPrivilegedHelperSupport
import SwiftUI

struct UsagePopoverView: View {
    let state: UsageMonitorState
    let onPreferencesChanged: () -> Void
    let onAction: (PetAction) -> Void

    @AppStorage(RunnerPreferences.popoverModuleKey) private var selectedModuleRaw = MacDogPopoverModule.codex.rawValue

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
        HStack(alignment: .top, spacing: 8) {
            contentSurface
            tabRail
        }
        .padding(10)
        .frame(width: 370, height: 408, alignment: .topLeading)
    }

    private var selectedModule: MacDogPopoverModule {
        MacDogPopoverModule(rawValue: selectedModuleRaw) ?? .codex
    }

    private var contentSurface: some View {
        VStack(alignment: .leading, spacing: 8) {
            textHeader
            Divider()

            tabContentContainer
        }
        .padding(12)
        .frame(width: 278, height: 388, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }

    private var tabRail: some View {
        VStack(spacing: 8) {
            ForEach(MacDogPopoverModule.allCases) { module in
                tabButton(module)
            }
        }
        .frame(width: 64)
    }

    private var textHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(selectedModule.title)
                .font(.headline)
                .lineLimit(1)
            Text(selectedModuleSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var tabContentContainer: some View {
        if selectedModule.usesScrollableContent {
            ScrollView {
                tabContent
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
        } else {
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedModule {
        case .codex:
            VStack(alignment: .leading, spacing: 10) {
                codexUsageContent
                RunnerControls(onChange: onPreferencesChanged)
            }
        case .mac:
            MacResourcesPanel(
                snapshot: state.systemMetrics,
                history: state.systemMetricsHistory
            )
        case .sleep:
            SleepPreventionPanel(
                sleepPreventionStatus: state.sleepPreventionStatus,
                sleepPreventionTriggerStatus: state.sleepPreventionTriggerStatus,
                privilegedHelperInstallSnapshot: state.privilegedHelperInstallSnapshot,
                onPreferencesChanged: onPreferencesChanged
            )
        case .battery:
            BatteryPanel(snapshot: state.systemMetrics)
        }
    }

    private func tabButton(_ module: MacDogPopoverModule) -> some View {
        let isSelected = selectedModule == module
        return Button {
            selectedModuleRaw = module.rawValue
            onPreferencesChanged()
        } label: {
            PopoverTabArtwork(
                resourceDirectory: MacDogCharacterProfile.codexPup.popoverTabs.resourceDirectory,
                resourceName: module.artworkName,
                fallbackSystemImage: module.systemImage
            )
            .frame(width: 64, height: 64)
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor.opacity(0.74) : Color.primary.opacity(0.14), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .help(module.title)
        .accessibilityLabel(module.title)
    }

    private var selectedModuleSubtitle: String {
        switch selectedModule {
        case .codex:
            return state.phase.statusLabel
        case .mac:
            return state.systemMetrics.cpuSummary
        case .sleep:
            return state.sleepPreventionStatus.summary
        case .battery:
            return state.systemMetrics.battery.summary
        }
    }

    private var codexUsageContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let limit = state.codexLimit {
                VStack(alignment: .leading, spacing: 12) {
                    UsageRow(title: "5시간", window: limit.fiveHour)
                    UsageRow(title: "주간", window: limit.weekly)
                }

                if let message = state.highUsageMessage {
                    PressureBanner(message: message, phase: state.phase)
                }

                Divider()

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    metadataRow("플랜", limit.planType ?? "알 수 없음")
                    metadataRow("갱신", state.lastUpdatedSummary)
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
    }

    private func metadataRow(_ key: String, _ value: String) -> some View {
        GridRow {
            Text(key)
                .foregroundStyle(.secondary)
            Text(value)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption)
    }
}

enum MacDogPopoverModule: String, CaseIterable, Identifiable {
    case codex
    case mac
    case sleep
    case battery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .codex:
            "Codex 사용량"
        case .mac:
            "활성 자원"
        case .sleep:
            "잠들지 않기"
        case .battery:
            "배터리"
        }
    }

    var tabLabel: String {
        switch self {
        case .codex:
            "Codex"
        case .mac:
            "Mac"
        case .sleep:
            "잠들지\n않기"
        case .battery:
            "배터리"
        }
    }

    var systemImage: String {
        MacDogCharacterProfile.codexPup.popoverTabs.artwork(for: self).systemImage
    }

    var artworkName: String {
        MacDogCharacterProfile.codexPup.popoverTabs.artwork(for: self).resourceName
    }

    var usesScrollableContent: Bool {
        switch self {
        case .sleep:
            true
        case .codex, .mac, .battery:
            false
        }
    }
}

private struct MacResourcesPanel: View {
    let snapshot: SystemMetricsSnapshot
    let history: SystemMetricsHistory

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ResourceTrendBlock(
                title: "CPU",
                systemImage: "cpu",
                value: snapshot.cpuSummary,
                details: [snapshot.cpuDetailSummary],
                values: trendValues(history.cpuLoadPercents, current: snapshot.cpuLoadPercent),
                tint: .blue
            )
            Divider()
            ResourceTrendBlock(
                title: "메모리",
                systemImage: "memorychip",
                value: snapshot.memorySummary,
                details: [snapshot.memoryDetailSummary],
                values: trendValues(history.memoryUsedPercents, current: snapshot.memoryUsedPercent),
                tint: .green
            )
            Divider()
            CompactResourceMetricBlock(
                title: "저장 용량",
                systemImage: "internaldrive",
                value: snapshot.diskSummary,
                details: [
                    snapshot.diskDetailSummary,
                    "홈 볼륨 기준"
                ],
                progress: snapshot.diskUsedPercent.map { Self.progress($0) }
            )
            Divider()
            CompactResourceMetricBlock(
                title: "네트워크",
                systemImage: "network",
                value: snapshot.primaryNetworkInterfaceName ?? "활성 인터페이스 \(snapshot.activeInterfaceCount)",
                details: [
                    snapshot.localNetworkSummary,
                    snapshot.networkRateSummary,
                    snapshot.networkSummary
                ],
                progress: nil
            )
        }
    }

    private static func progress(_ percent: Double) -> Double {
        min(max(percent / 100, 0), 1)
    }

    private func trendValues(_ values: [Double], current: Double?) -> [Double] {
        if values.isEmpty, let current {
            return [current]
        }
        return values
    }
}

private struct ResourceTrendBlock: View {
    let title: String
    let systemImage: String
    let value: String
    let details: [String]
    let values: [Double]
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }

                ForEach(details, id: \.self) { detail in
                    Text(detail)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                SparklineView(values: values, tint: tint)
                    .frame(height: 30)
                    .padding(.top, 2)
            }
        }
    }
}

private struct CompactResourceMetricBlock: View {
    let title: String
    let systemImage: String
    let value: String
    let details: [String]
    let progress: Double?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                ForEach(details, id: \.self) { detail in
                    Text(detail)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                if let progress {
                    ProgressView(value: progress)
                        .controlSize(.mini)
                        .tint(.accentColor)
                        .padding(.top, 1)
                }
            }
        }
    }
}

private struct SparklineView: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.045))

                Path { path in
                    addLine(to: &path, in: geometry.size)
                }
                .stroke(tint, style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
            }
        }
        .accessibilityHidden(true)
    }

    private func addLine(to path: inout Path, in size: CGSize) {
        let clampedValues = values.map { min(max($0, 0), 100) }
        guard let first = clampedValues.first else { return }

        if clampedValues.count == 1 {
            let y = yPosition(for: first, height: size.height)
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            return
        }

        let stepX = size.width / CGFloat(clampedValues.count - 1)
        for (index, value) in clampedValues.enumerated() {
            let point = CGPoint(
                x: CGFloat(index) * stepX,
                y: yPosition(for: value, height: size.height)
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
    }

    private func yPosition(for value: Double, height: CGFloat) -> CGFloat {
        let normalized = CGFloat(value / 100)
        return height - (normalized * height)
    }
}

private struct SleepPreventionPanel: View {
    let sleepPreventionStatus: SleepPreventionStatus
    let sleepPreventionTriggerStatus: SleepPreventionTriggerStatus
    let privilegedHelperInstallSnapshot: PrivilegedHelperInstallSnapshot
    let onPreferencesChanged: () -> Void

    @AppStorage(RunnerPreferences.sleepPreventionControlModeKey) private var sleepPreventionControlMode = RunnerPreferences.defaultSleepPreventionControlMode.rawValue
    @AppStorage(RunnerPreferences.sleepPreventionSessionPresetKey) private var sleepPreventionSessionPreset = RunnerPreferences.defaultSleepPreventionSessionPreset.rawValue
    @AppStorage(RunnerPreferences.sleepPreventionPowerAdapterTriggerKey) private var powerAdapterTriggerEnabled = false
    @AppStorage(RunnerPreferences.sleepPreventionCodexAppTriggerKey) private var codexAppTriggerEnabled = false
    @AppStorage(RunnerPreferences.sleepPreventionChargingBelowThresholdTriggerKey) private var chargingBelowThresholdTriggerEnabled = false
    @AppStorage(RunnerPreferences.sleepPreventionCPUThresholdTriggerKey) private var cpuThresholdTriggerEnabled = false
    @AppStorage(RunnerPreferences.sleepPreventionNetworkActivityTriggerKey) private var networkActivityTriggerEnabled = false
    @AppStorage(RunnerPreferences.sleepPreventionExternalVolumeTriggerKey) private var externalVolumeTriggerEnabled = false
    @AppStorage(RunnerPreferences.sleepPreventionBatteryThresholdPercentKey) private var batteryThresholdPercent = RunnerPreferences.defaultSleepPreventionBatteryThresholdPercent
    @AppStorage(RunnerPreferences.sleepPreventionCPUThresholdPercentKey) private var cpuThresholdPercent = RunnerPreferences.defaultSleepPreventionCPUThresholdPercent
    @AppStorage(RunnerPreferences.sleepPreventionNetworkThresholdKBPerSecondKey) private var networkThresholdKBPerSecond = RunnerPreferences.defaultSleepPreventionNetworkThresholdKBPerSecond
    @AppStorage(RunnerPreferences.sleepPreventionAppMatchTextKey) private var appMatchText = RunnerPreferences.defaultSleepPreventionAppMatchText
    @AppStorage(RunnerPreferences.sleepPreventionPreventDisplaySleepKey) private var preventDisplaySleep = RunnerPreferences.defaultSleepPreventionPreventDisplaySleep
    @AppStorage(RunnerPreferences.sleepPreventionPreventClosedLidSleepKey) private var preventClosedLidSleep = RunnerPreferences.defaultSleepPreventionPreventClosedLidSleep
    @AppStorage(RunnerPreferences.sleepPreventionDisableScreenLockKey) private var disableScreenLock = RunnerPreferences.defaultSleepPreventionDisableScreenLock

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PopoverFormSection(title: "제어 방식", systemImage: "power") {
                controlModeButtons

                Text(controlModeSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if currentControlMode == .time {
                PopoverFormSection(title: "유지 시간", systemImage: "timer") {
                    sessionPresetButtons

                    Text("선택한 시간 동안 덮개 닫힘 보호까지 유지하고, 만료되면 원복합니다.")
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

            PopoverFormSection(title: "세션 옵션", systemImage: "display") {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                    GridRow {
                        triggerToggle("화면 잠자기 방지", isOn: $preventDisplaySleep)
                        triggerToggle("덮개 닫힘 보호", isOn: $preventClosedLidSleep)
                    }
                    GridRow {
                        triggerToggle("잠금 요구 해제", isOn: $disableScreenLock)
                        Text(screenLockPolicyNote)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                }
            }

            PopoverFormSection(title: "권한 도우미", systemImage: "key.horizontal") {
                helperStatusRow

                Text(privilegedHelperInstallSnapshot.detailSummary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                helperGuidance
            }

            if currentControlMode == .condition {
                PopoverFormSection(title: "상태 기준", systemImage: "switch.2") {
                    Text("체크한 조건 중 하나라도 맞으면 잠들지 않게 유지합니다.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                        GridRow {
                            triggerToggle("전원 연결", isOn: $powerAdapterTriggerEnabled)
                            triggerToggle("\(effectiveAppMatchText) 앱", isOn: $codexAppTriggerEnabled)
                        }
                        GridRow {
                            triggerToggle("충전 \(effectiveBatteryThresholdPercent)% 미만", isOn: $chargingBelowThresholdTriggerEnabled)
                            triggerToggle("CPU \(effectiveCPUThresholdPercent)% 이상", isOn: $cpuThresholdTriggerEnabled)
                        }
                        GridRow {
                            triggerToggle("네트워크 \(effectiveNetworkThresholdKBPerSecond)KB/s", isOn: $networkActivityTriggerEnabled)
                            triggerToggle("외장/네트워크 볼륨", isOn: $externalVolumeTriggerEnabled)
                        }
                    }
                }

                PopoverFormSection(title: "세부 기준", systemImage: "slider.horizontal.3") {
                    VStack(alignment: .leading, spacing: 7) {
                        thresholdSlider(
                            title: "충전 기준",
                            valueText: "\(effectiveBatteryThresholdPercent)%",
                            value: batteryThresholdBinding,
                            range: Double(RunnerPreferences.minimumSleepPreventionBatteryThresholdPercent)...Double(RunnerPreferences.maximumSleepPreventionBatteryThresholdPercent),
                            step: 5
                        )
                        thresholdSlider(
                            title: "CPU 기준",
                            valueText: "\(effectiveCPUThresholdPercent)%",
                            value: cpuThresholdBinding,
                            range: Double(RunnerPreferences.minimumSleepPreventionCPUThresholdPercent)...Double(RunnerPreferences.maximumSleepPreventionCPUThresholdPercent),
                            step: 5
                        )
                        thresholdSlider(
                            title: "네트워크",
                            valueText: "\(effectiveNetworkThresholdKBPerSecond)KB/s",
                            value: networkThresholdBinding,
                            range: Double(RunnerPreferences.minimumSleepPreventionNetworkThresholdKBPerSecond)...Double(RunnerPreferences.maximumSleepPreventionNetworkThresholdKBPerSecond),
                            step: 10
                        )

                        HStack(spacing: 6) {
                            Text("앱")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 54, alignment: .leading)
                            TextField("앱 이름 또는 번들 ID", text: $appMatchText)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)
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
        .onChange(of: networkActivityTriggerEnabled) { _, enabled in
            RunnerPreferences.setSleepPreventionNetworkActivityTrigger(enabled)
            deferredPreferencesChanged()
        }
        .onChange(of: externalVolumeTriggerEnabled) { _, enabled in
            RunnerPreferences.setSleepPreventionExternalVolumeTrigger(enabled)
            deferredPreferencesChanged()
        }
        .onChange(of: appMatchText) { _, value in
            RunnerPreferences.setSleepPreventionAppMatchText(value)
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
                .frame(maxWidth: .infinity, minHeight: 24)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isSelected ? Color.accentColor : Color.clear)
                )
        }
        .buttonStyle(.plain)
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

    private var effectiveNetworkThresholdKBPerSecond: Int {
        RunnerPreferences.normalizedSleepPreventionNetworkThresholdKBPerSecond(networkThresholdKBPerSecond)
    }

    private var effectiveAppMatchText: String {
        RunnerPreferences.normalizedSleepPreventionAppMatchText(appMatchText)
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

    private var screenLockPolicyNote: String {
        disableScreenLock ? "보호기 후 암호 요구 해제" : "잠금 설정 유지"
    }

    private var helperStatusRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(helperStatusColor)
                .frame(width: 7, height: 7)
            Text(privilegedHelperInstallSnapshot.summary)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Spacer(minLength: 0)
        }
    }

    private var helperStatusColor: Color {
        switch privilegedHelperInstallSnapshot.status {
        case .missing:
            Color.secondary
        case .partial:
            Color.orange
        case .installed:
            Color.green
        }
    }

    private var helperGuidance: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(
                privilegedHelperInstallSnapshot.guidanceTitle,
                systemImage: privilegedHelperInstallSnapshot.requiresUserAction ? "exclamationmark.shield" : "checkmark.shield"
            )
            .font(.caption2.weight(.semibold))
            .foregroundStyle(privilegedHelperInstallSnapshot.requiresUserAction ? Color.orange : Color.green)

            Text(privilegedHelperInstallSnapshot.guidanceDetail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 1)
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

    private var networkThresholdBinding: Binding<Double> {
        Binding(
            get: { Double(effectiveNetworkThresholdKBPerSecond) },
            set: { newValue in
                let value = RunnerPreferences.normalizedSleepPreventionNetworkThresholdKBPerSecond(Int(newValue.rounded()))
                RunnerPreferences.setSleepPreventionNetworkThresholdKBPerSecond(value)
                networkThresholdKBPerSecond = value
                deferredPreferencesChanged()
            }
        )
    }

    private func triggerToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .toggleStyle(.checkbox)
            .font(.caption)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
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
                .frame(width: 54, alignment: .leading)
            Slider(value: value, in: range, step: step)
                .controlSize(.mini)
            Text(valueText)
                .font(.caption2.monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .frame(width: 48, alignment: .trailing)
        }
        .frame(height: 20)
    }
}

private struct BatteryPanel: View {
    let snapshot: SystemMetricsSnapshot

    @AppStorage(RunnerPreferences.chargeLimitTargetPercentKey) private var chargeLimitTargetPercent = RunnerPreferences.defaultChargeLimitTargetPercent
    @State private var appliedChargeLimitPercent: Int?
    @State private var chargeLimitErrorMessage: String?

    private let chargeLimitController = NativeChargeLimitController()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ResourceMetricBlock(
                title: "배터리",
                systemImage: "battery.100percent",
                value: snapshot.battery.summary,
                details: [
                    snapshot.battery.powerSummary,
                    snapshot.battery.detailSummary
                ],
                progress: snapshot.battery.percent.map { Double($0) / 100 }
            )

            PopoverFormSection(title: "충전 제어", systemImage: "slider.horizontal.3") {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                    GridRow {
                        metricRow("상태", chargeLimitSummary)
                    }
                    GridRow {
                        metricRow("사양", snapshot.chargeLimitSupport.requirementSummary)
                    }
                    GridRow {
                        metricRow("목표", "\(effectiveChargeLimitTargetPercent)%", emphasized: true)
                    }
                    GridRow {
                        metricRow("동작", chargeLimitBehaviorSummary)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("\(RunnerPreferences.minimumChargeLimitTargetPercent)%")
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                        Text("\(RunnerPreferences.maximumChargeLimitTargetPercent)%")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption2)

                    Slider(
                        value: chargeLimitTargetBinding,
                        in: Double(chargeLimitRange.lowerBound)...Double(chargeLimitRange.upperBound),
                        step: Double(RunnerPreferences.chargeLimitTargetStepPercent)
                    )
                    .disabled(!snapshot.chargeLimitSupport.isNativeChargeLimitAvailable)
                }

                Text("목표보다 높으면 강제 방전하지 않고 충전을 멈춘 뒤 자연 하강합니다.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let chargeLimitErrorMessage {
                    Text(chargeLimitErrorMessage)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onAppear {
            appliedChargeLimitPercent = snapshot.chargeLimitSupport.currentLimitPercent
        }
    }

    private var chargeLimitSummary: String {
        if let appliedChargeLimitPercent {
            return "macOS 적용됨 · \(appliedChargeLimitPercent)%"
        }
        return snapshot.chargeLimitSupport.summary
    }

    private var chargeLimitBehaviorSummary: String {
        guard snapshot.chargeLimitSupport.isNativeChargeLimitAvailable else {
            return "시스템 설정 확인 필요"
        }
        guard let percent = snapshot.battery.percent else {
            return "배터리 상태 확인 중"
        }
        if percent > effectiveChargeLimitTargetPercent, snapshot.battery.isConnectedToPower == true {
            return snapshot.battery.isCharging == true ? "목표 초과 · 충전 중" : "목표 초과 · 충전 안 함"
        }
        if snapshot.battery.isCharging == true {
            return "목표까지 충전 중"
        }
        return "상한 유지"
    }

    private var effectiveChargeLimitTargetPercent: Int {
        RunnerPreferences.normalizedChargeLimitTargetPercent(
            appliedChargeLimitPercent ?? snapshot.chargeLimitSupport.currentLimitPercent ?? chargeLimitTargetPercent
        )
    }

    private var chargeLimitRange: ClosedRange<Int> {
        guard
            let lowerBound = snapshot.chargeLimitSupport.availableLimits.first,
            let upperBound = snapshot.chargeLimitSupport.availableLimits.last
        else {
            return RunnerPreferences.minimumChargeLimitTargetPercent...RunnerPreferences.maximumChargeLimitTargetPercent
        }
        return lowerBound...upperBound
    }

    private var chargeLimitTargetBinding: Binding<Double> {
        Binding(
            get: {
                Double(effectiveChargeLimitTargetPercent)
            },
            set: { newValue in
                let percent = RunnerPreferences.normalizedChargeLimitTargetPercent(Int(newValue.rounded()))
                do {
                    let appliedPercent = try chargeLimitController.setLimitPercent(percent)
                    RunnerPreferences.setChargeLimitTargetPercent(appliedPercent)
                    chargeLimitTargetPercent = appliedPercent
                    appliedChargeLimitPercent = appliedPercent
                    chargeLimitErrorMessage = nil
                } catch {
                    chargeLimitErrorMessage = "적용 실패 · \(error.localizedDescription)"
                }
            }
        )
    }

    private func metricRow(_ key: String, _ value: String, emphasized: Bool = false) -> some View {
        GridRow {
            Text(key)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(emphasized ? .callout.weight(.bold) : .caption)
                .monospacedDigit()
                .foregroundStyle(emphasized ? Color.accentColor : Color.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ResourceMetricBlock: View {
    let title: String
    let systemImage: String
    let value: String
    let details: [String]
    let progress: Double?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(title): \(value)")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(details, id: \.self) { detail in
                    Text(detail)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let progress {
                    ProgressView(value: progress)
                        .tint(.accentColor)
                        .padding(.top, 2)
                }
            }
        }
    }
}

private struct PopoverFormSection<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content
        }
    }
}

private struct PopoverTabArtwork: View {
    let resourceDirectory: String
    let resourceName: String
    let fallbackSystemImage: String

    var body: some View {
        Group {
            if let image = Self.image(named: resourceName, resourceDirectory: resourceDirectory) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))
                    Image(systemName: fallbackSystemImage)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private static func image(named resourceName: String, resourceDirectory: String) -> NSImage? {
        let localResourceURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent("MacDog", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent(resourceDirectory, isDirectory: true)
            .appendingPathComponent("\(resourceName).png")
        if FileManager.default.fileExists(atPath: localResourceURL.path) {
            return NSImage(contentsOf: localResourceURL)
        }

        if let url = Bundle.main.resourceURL?
            .appendingPathComponent(resourceDirectory, isDirectory: true)
            .appendingPathComponent("\(resourceName).png") {
            return NSImage(contentsOf: url)
        }

        if let url = Bundle.main.resourceURL?.appendingPathComponent("\(resourceName).png") {
            return NSImage(contentsOf: url)
        }

        if let url = Bundle.module.url(
            forResource: resourceName,
            withExtension: "png",
            subdirectory: resourceDirectory
        ) {
            return NSImage(contentsOf: url)
        }

        guard let url = Bundle.module.url(forResource: resourceName, withExtension: "png") else {
            return nil
        }

        return NSImage(contentsOf: url)
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
        VStack(alignment: .leading, spacing: 7) {
            Divider()

            Picker("러너 속도", selection: $displayBasis) {
                ForEach(UsageDisplayBasis.allCases) { basis in
                    Text(basis.label).tag(basis.rawValue)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .help("러너 속도를 조절할 사용량 기준을 선택합니다.")

            HStack(spacing: 10) {
                Toggle("움직임 줄이기", isOn: $reducedMotion)
                Toggle("일시 정지", isOn: $animationPaused)
            }
            .font(.caption)
        }
        .onChange(of: displayBasis) { _, _ in onChange() }
        .onChange(of: reducedMotion) { _, _ in onChange() }
        .onChange(of: animationPaused) { _, _ in onChange() }
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
