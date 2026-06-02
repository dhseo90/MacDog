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
        .padding(MacDogPopoverLayout.outerPadding)
        .frame(
            width: MacDogPopoverLayout.outerSize.width,
            height: MacDogPopoverLayout.outerSize.height,
            alignment: .topLeading
        )
        .background(
            RoundedRectangle(cornerRadius: MacDogPopoverLayout.shellCornerRadius)
                .fill(MacDogPopoverLayout.shellBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: MacDogPopoverLayout.shellCornerRadius)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }

    private var selectedModule: MacDogPopoverModule {
        MacDogPopoverModule(rawValue: selectedModuleRaw) ?? .codex
    }

    private var contentSurface: some View {
        VStack(alignment: .leading, spacing: MacDogPopoverLayout.contentStackSpacing) {
            textHeader
            Divider()

            tabContentContainer
        }
        .padding(MacDogPopoverLayout.contentPadding)
        .frame(
            width: MacDogPopoverLayout.contentSurfaceSize.width,
            height: MacDogPopoverLayout.contentSurfaceSize.height,
            alignment: .topLeading
        )
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
            codexUsageContent
        case .mac:
            MacResourcesPanel(
                snapshot: state.systemMetrics,
                history: state.systemMetricsHistory
            )
        case .sleep:
            SleepPreventionPanel(
                sleepPreventionStatus: state.sleepPreventionStatus,
                sleepPreventionTriggerStatus: state.sleepPreventionTriggerStatus,
                onAction: onAction,
                onPreferencesChanged: onPreferencesChanged
            )
        case .battery:
            BatteryPanel(snapshot: state.systemMetrics)
        case .settings:
            SettingsPanel(
                privilegedHelperInstallSnapshot: state.privilegedHelperInstallSnapshot,
                onAction: onAction,
                onPreferencesChanged: onPreferencesChanged
            )
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
        case .settings:
            return "앱 설정"
        }
    }

    private var codexUsageContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let limit = state.codexLimit {
                VStack(alignment: .leading, spacing: 12) {
                    UsageRow(title: "5시간", window: limit.fiveHour)
                    UsageRow(title: "주간", window: limit.weekly)
                }

                Divider()

                WeeklyRemainingHistoryBlock(
                    history: state.weeklyUsageHistory,
                    weeklyWindow: limit.weekly,
                    currentReport: state.report,
                    currentTimestamp: state.cacheSnapshot?.cachedAt ?? state.report?.generatedAt
                )

                if let message = state.highUsageMessage {
                    PressureBanner(message: message, phase: state.phase)
                }

                Divider()

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    metadataRow("플랜", limit.planType ?? "알 수 없음")
                    metadataRow("갱신", state.lastUpdatedSummary)
                    resetMetadataRow(limit.weekly)
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

    private func resetMetadataRow(_ window: UsageWindowReport?) -> some View {
        metadataRow("초기화", resetMetadataValue(window))
    }

    private func resetMetadataValue(_ window: UsageWindowReport?) -> String {
        let summary = UsageWindowStatus.resetSummary(resetsAt: window?.resetsAt)
        if summary.hasPrefix("초기화까지 ") {
            return String(summary.dropFirst("초기화까지 ".count))
        }
        if summary.hasPrefix("초기화 ") {
            return String(summary.dropFirst("초기화 ".count))
        }
        return summary
    }
}

enum MacDogPopoverModule: String, CaseIterable, Identifiable {
    case codex
    case mac
    case sleep
    case battery
    case settings

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
        case .settings:
            "설정"
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
        case .settings:
            "설정"
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
        case .codex, .mac, .sleep, .battery, .settings:
            false
        }
    }
}

enum MacDogPopoverLayout {
    static let outerSize = CGSize(width: 370, height: 408)
    static let outerPadding: CGFloat = 10
    static let contentSurfaceSize = CGSize(width: 278, height: 388)
    static let contentPadding: CGFloat = 12
    static let contentStackSpacing: CGFloat = 8
    static let headerHeight: CGFloat = 34
    static let dividerHeight: CGFloat = 1
    static let shellCornerRadius: CGFloat = 12
    static let shellBackgroundColor = Color(red: 0.12, green: 0.12, blue: 0.14).opacity(0.96)

    static var nonScrollableContentHeight: CGFloat {
        contentSurfaceSize.height
            - (contentPadding * 2)
            - headerHeight
            - dividerHeight
            - (contentStackSpacing * 2)
    }
}

enum CodexUsagePanelLayout {
    static let weeklyGraphHeight: CGFloat = 74
    static let weeklyGraphYAxisWidth: CGFloat = 28
    static let weeklyGraphAxisSpacing: CGFloat = 5
    static let weeklyGraphTimelineHeight: CGFloat = 13

    static var weeklyGraphPlotStartX: CGFloat {
        weeklyGraphYAxisWidth + weeklyGraphAxisSpacing
    }
}

enum MacResourcesPanelLayout {
    static let verticalSpacing: CGFloat = 8
    static let sparklineHeight: CGFloat = 30
    static let trendBlockHeight: CGFloat = 68
    static let storageBlockHeight: CGFloat = 54
    static let networkBlockHeight: CGFloat = 56

    static var estimatedContentHeight: CGFloat {
        (trendBlockHeight * 2)
            + storageBlockHeight
            + networkBlockHeight
            + (MacDogPopoverLayout.dividerHeight * 3)
            + (verticalSpacing * 6)
    }
}

private struct MacResourcesPanel: View {
    let snapshot: SystemMetricsSnapshot
    let history: SystemMetricsHistory

    var body: some View {
        VStack(alignment: .leading, spacing: MacResourcesPanelLayout.verticalSpacing) {
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
                    .frame(height: MacResourcesPanelLayout.sparklineHeight)
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
                    let centerY = geometry.size.height / 2
                    path.move(to: CGPoint(x: 0, y: centerY))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: centerY))
                }
                .stroke(Color.primary.opacity(0.14), style: StrokeStyle(lineWidth: 0.7, dash: [3, 4]))

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
        let scale = SparklineScale(values: clampedValues)

        if clampedValues.count == 1 {
            let y = yPosition(for: first, height: size.height, scale: scale)
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            return
        }

        let stepX = size.width / CGFloat(clampedValues.count - 1)
        for (index, value) in clampedValues.enumerated() {
            let point = CGPoint(
                x: CGFloat(index) * stepX,
                y: yPosition(for: value, height: size.height, scale: scale)
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
    }

    private func yPosition(for value: Double, height: CGFloat, scale: SparklineScale) -> CGFloat {
        let normalized = CGFloat(scale.normalized(value))
        return height - (normalized * height)
    }
}

struct SparklineScale: Equatable {
    static let lowerBound: Double = 0
    static let upperBound: Double = 100

    init(values: [Double]) {
        _ = values
    }

    func normalized(_ value: Double) -> Double {
        let clampedValue = min(max(value, 0), 100)
        let span = Self.upperBound - Self.lowerBound
        guard span > 0 else { return 0.5 }
        return min(max((clampedValue - Self.lowerBound) / span, 0), 1)
    }
}

private struct SleepPreventionPanel: View {
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
                    .fixedSize(horizontal: false, vertical: true)
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
                PopoverFormSection(title: "상태 기준", systemImage: "switch.2") {
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

private struct SettingsPanel: View {
    let privilegedHelperInstallSnapshot: PrivilegedHelperInstallSnapshot
    let onAction: (PetAction) -> Void
    let onPreferencesChanged: () -> Void

    @AppStorage(RunnerPreferences.desktopPetEnabledKey) private var desktopPetEnabled = false
    @AppStorage(RunnerPreferences.reducedMotionKey) private var reducedMotion = false
    @AppStorage(RunnerPreferences.animationPausedKey) private var animationPaused = false
    @AppStorage(RunnerPreferences.loginLaunchEnabledKey) private var loginLaunchEnabled = RunnerPreferences.defaultLoginLaunchEnabled
    @State private var loginLaunchErrorMessage: String?

    private let loginLaunchController = LoginLaunchController()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PopoverFormSection(title: "앱 실행", systemImage: "power") {
                VStack(alignment: .leading, spacing: 5) {
                    settingsToggle("로그인 시 MacDog 실행", isOn: $loginLaunchEnabled)
                    Text("끄면 재부팅 후 로그인해도 MacDog가 자동으로 실행되지 않습니다.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let loginLaunchErrorMessage {
                        Text(loginLaunchErrorMessage)
                            .font(.caption2)
                            .foregroundStyle(Color.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Divider()

            PopoverFormSection(title: "권한 도우미", systemImage: "key.horizontal") {
                PrivilegedHelperStatusContent(
                    snapshot: privilegedHelperInstallSnapshot,
                    onAction: onAction
                )
            }

            Divider()

            PopoverFormSection(title: "캐릭터 설정", systemImage: "pawprint") {
                VStack(alignment: .leading, spacing: 8) {
                    CharacterSelectionRow(profile: MacDogCharacterProfile.codexPup)

                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        settingsToggle("데스크톱 펫 표시", isOn: $desktopPetEnabled)
                        settingsToggle("움직임 줄이기", isOn: $reducedMotion)
                        settingsToggle("러너 일시정지", isOn: $animationPaused)
                    }
                }
            }
        }
        .onChange(of: desktopPetEnabled) { _, enabled in
            RunnerPreferences.setDesktopPetEnabled(enabled)
            deferredPreferencesChanged()
        }
        .onChange(of: reducedMotion) { _, enabled in
            RunnerPreferences.setReducedMotion(enabled)
            deferredPreferencesChanged()
        }
        .onChange(of: animationPaused) { _, enabled in
            RunnerPreferences.setAnimationPaused(enabled)
            deferredPreferencesChanged()
        }
        .onChange(of: loginLaunchEnabled) { _, enabled in
            RunnerPreferences.setLoginLaunchEnabled(enabled)
            do {
                try loginLaunchController.setEnabled(enabled)
                loginLaunchErrorMessage = nil
            } catch {
                loginLaunchErrorMessage = error.localizedDescription
            }
            deferredPreferencesChanged()
        }
    }

    private func settingsToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .toggleStyle(.checkbox)
            .controlSize(.small)
            .font(.caption2.weight(.medium))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
    }

    private func deferredPreferencesChanged() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            onPreferencesChanged()
        }
    }
}

private struct CharacterSelectionRow: View {
    let profile: MacDogCharacterProfile

    var body: some View {
        HStack(spacing: 10) {
            CharacterPreview(profile: profile)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                Text("기본 캐릭터")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Label("선택됨", systemImage: "checkmark.circle.fill")
                .labelStyle(.titleAndIcon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .lineLimit(1)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.accentColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.accentColor.opacity(0.38), lineWidth: 1)
        )
    }
}

private struct CharacterPreview: View {
    let profile: MacDogCharacterProfile

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                )

            if let previewImage {
                Image(nsImage: previewImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 38, height: 38)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 42, height: 42)
        .accessibilityHidden(true)
    }

    private var previewImage: NSImage? {
        let asset = profile.desktopPet.asset(for: .idleFront)
        if let image = Self.image(
            named: "\(asset.resourcePrefix)-0",
            resourceDirectory: profile.desktopPet.resourceDirectory
        ) {
            return Self.croppedVisibleImage(image)
        }

        return Self.image(
            named: MacDogPopoverModule.settings.artworkName,
            resourceDirectory: profile.popoverTabs.resourceDirectory
        )
    }

    private static func image(named resourceName: String, resourceDirectory: String) -> NSImage? {
        if let url = Bundle.main.resourceURL?
            .appendingPathComponent(resourceDirectory, isDirectory: true)
            .appendingPathComponent("\(resourceName).png") {
            if let image = NSImage(contentsOf: url) {
                return image
            }
        }

        if let url = Bundle.main.resourceURL?.appendingPathComponent("\(resourceName).png") {
            if let image = NSImage(contentsOf: url) {
                return image
            }
        }

        if let url = Bundle.module.url(
            forResource: resourceName,
            withExtension: "png",
            subdirectory: resourceDirectory
        ) {
            if let image = NSImage(contentsOf: url) {
                return image
            }
        }

        guard let url = Bundle.module.url(forResource: resourceName, withExtension: "png") else {
            return nil
        }

        return NSImage(contentsOf: url)
    }

    private static func croppedVisibleImage(_ image: NSImage) -> NSImage {
        guard
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff)
        else {
            return image
        }

        var minX = bitmap.pixelsWide
        var minY = bitmap.pixelsHigh
        var maxX = 0
        var maxY = 0

        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard let color = bitmap.colorAt(x: x, y: y), color.alphaComponent > 0.02 else {
                    continue
                }

                minX = Swift.min(minX, x)
                minY = Swift.min(minY, y)
                maxX = Swift.max(maxX, x)
                maxY = Swift.max(maxY, y)
            }
        }

        guard minX <= maxX, minY <= maxY else {
            return image
        }

        let padding = 2
        let x = Swift.max(0, minX - padding)
        let right = Swift.min(bitmap.pixelsWide, maxX + padding + 1)
        let top = Swift.max(0, minY - padding)
        let bottom = Swift.min(bitmap.pixelsHigh, maxY + padding + 1)
        let y = bitmap.pixelsHigh - bottom
        let cropRect = NSRect(x: x, y: y, width: right - x, height: bottom - top)
        let cropped = NSImage(size: cropRect.size)

        cropped.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: cropRect.size),
            from: cropRect,
            operation: .sourceOver,
            fraction: 1
        )
        cropped.unlockFocus()
        return cropped
    }
}

private struct SettingsCategoryHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.primary)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct PrivilegedHelperStatusContent: View {
    let snapshot: PrivilegedHelperInstallSnapshot
    let onAction: (PetAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)
                Text(snapshot.summary)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Spacer(minLength: 0)
            }

            Text(snapshot.detailSummary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Label(
                snapshot.guidanceTitle,
                systemImage: snapshot.requiresUserAction ? "exclamationmark.shield" : "checkmark.shield"
            )
            .font(.caption2.weight(.semibold))
            .foregroundStyle(snapshot.requiresUserAction ? Color.orange : Color.green)

            helperActionButtons
        }
    }

    private var statusColor: Color {
        switch snapshot.status {
        case .missing:
            Color.secondary
        case .partial:
            Color.orange
        case .installed:
            Color.green
        }
    }

    @ViewBuilder
    private var helperActionButtons: some View {
        let actions = PrivilegedHelperPopoverAction.actions(for: snapshot)

        if actions.count > 1 {
            HStack(spacing: 6) {
                ForEach(actions) { action in
                    helperActionButton(action)
                }
            }
        } else if let action = actions.first {
            helperActionButton(action)
        }
    }

    private func helperActionButton(_ action: PrivilegedHelperPopoverAction) -> some View {
        Button {
            onAction(action.action)
        } label: {
            Label(action.title, systemImage: action.systemImage)
                .font(.caption2.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(.top, 1)
    }
}

private struct BatteryPanel: View {
    let snapshot: SystemMetricsSnapshot

    @AppStorage(RunnerPreferences.chargeLimitTargetPercentKey) private var chargeLimitTargetPercent = RunnerPreferences.defaultChargeLimitTargetPercent
    @State private var appliedChargeLimitPercent: Int?
    @State private var chargeLimitErrorMessage: String?

    private let chargeLimitController = NativeChargeLimitController()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ResourceMetricBlock(
                title: "배터리",
                systemImage: "battery.100percent",
                value: snapshot.battery.summary,
                details: [
                    snapshot.battery.powerSummary
                ],
                progress: snapshot.battery.percent.map { Double($0) / 100 }
            )

            Divider()

            PopoverFormSection(title: "배터리 정보", systemImage: "info.circle") {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                    GridRow {
                        metricRow("사이클", snapshot.battery.cycleSummary)
                    }
                    GridRow {
                        metricRow("온도", snapshot.battery.temperatureSummary)
                    }
                }
            }

            Divider()

            PopoverFormSection(title: "충전 제어", systemImage: "slider.horizontal.3") {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                    GridRow {
                        metricRow("현재 한도", chargeLimitSummary)
                    }
                    if !snapshot.chargeLimitSupport.isNativeChargeLimitAvailable {
                        GridRow {
                            metricRow("필요 조건", snapshot.chargeLimitSupport.requirementSummary)
                        }
                    }
                    GridRow {
                        metricRow("설정값", "\(effectiveChargeLimitTargetPercent)%", emphasized: true)
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

                Text(snapshot.chargeLimitSupport.guidanceSummary)
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
            return "\(appliedChargeLimitPercent)% 적용됨"
        }
        if let currentLimitPercent = snapshot.chargeLimitSupport.currentLimitPercent {
            return "\(currentLimitPercent)% 적용됨"
        }
        return snapshot.chargeLimitSupport.summary
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
        VStack(alignment: .leading, spacing: 5) {
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
        if let url = Bundle.main.resourceURL?
            .appendingPathComponent(resourceDirectory, isDirectory: true)
            .appendingPathComponent("\(resourceName).png") {
            if let image = NSImage(contentsOf: url) {
                return image
            }
        }

        if let url = Bundle.main.resourceURL?.appendingPathComponent("\(resourceName).png") {
            if let image = NSImage(contentsOf: url) {
                return image
            }
        }

        if let url = Bundle.module.url(
            forResource: resourceName,
            withExtension: "png",
            subdirectory: resourceDirectory
        ) {
            if let image = NSImage(contentsOf: url) {
                return image
            }
        }

        guard let url = Bundle.module.url(forResource: resourceName, withExtension: "png") else {
            return nil
        }

        return NSImage(contentsOf: url)
    }
}

private struct WeeklyRemainingHistoryBlock: View {
    let history: CodexUsageWeeklyHistory
    let weeklyWindow: UsageWindowReport?
    let currentReport: CodexUsageReport?
    let currentTimestamp: Int?

    private var chart: WeeklyRemainingHistoryChart {
        WeeklyRemainingHistoryChart(
            history: history,
            weeklyWindow: weeklyWindow,
            currentSample: currentSample
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("주간 잔여량")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(chart.summaryText)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            WeeklyRemainingHistoryGraph(chart: chart)
                .frame(height: CodexUsagePanelLayout.weeklyGraphHeight)

            WeeklyRemainingTimelineLabels(
                startLabel: chart.resetStartLabel,
                endLabel: chart.resetEndLabel
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("주간 잔여량 그래프")
        .accessibilityValue(chart.accessibilityValue)
    }

    private var currentSample: CodexUsageWeeklyHistorySample? {
        guard let currentReport,
              let currentTimestamp
        else {
            return nil
        }

        return CodexUsageWeeklyHistorySample(
            report: currentReport,
            recordedAt: currentTimestamp
        )
    }
}

private struct WeeklyRemainingTimelineLabels: View {
    let startLabel: String
    let endLabel: String

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Text(startLabel)
                    .position(
                        x: CodexUsagePanelLayout.weeklyGraphPlotStartX,
                        y: CodexUsagePanelLayout.weeklyGraphTimelineHeight / 2
                    )

                Text(endLabel)
                    .frame(width: geometry.size.width, alignment: .trailing)
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        .frame(height: CodexUsagePanelLayout.weeklyGraphTimelineHeight)
    }
}

private struct WeeklyRemainingHistoryGraph: View {
    let chart: WeeklyRemainingHistoryChart

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: CodexUsagePanelLayout.weeklyGraphAxisSpacing) {
                yAxisLabels
                    .frame(width: CodexUsagePanelLayout.weeklyGraphYAxisWidth, height: geometry.size.height)

                WeeklyRemainingHistoryPlot(chart: chart, tint: tint)
                    .frame(
                        width: max(
                            0,
                            geometry.size.width -
                                CodexUsagePanelLayout.weeklyGraphPlotStartX
                        ),
                        height: geometry.size.height
                    )
            }
        }
    }

    private var tint: Color {
        switch chart.latestActualPoint?.remainingPercent ?? 100 {
        case ..<10:
            .red
        case 10..<30:
            .orange
        case 30..<60:
            .yellow
        default:
            .green
        }
    }
}

private var yAxisLabels: some View {
    VStack(alignment: .trailing) {
        Text("100%")
        Spacer()
        Text("50%")
        Spacer()
        Text("0%")
    }
    .font(.caption2.weight(.medium))
    .foregroundStyle(.secondary.opacity(0.76))
    .lineLimit(1)
    .minimumScaleFactor(0.72)
}

private struct WeeklyRemainingHistoryPlot: View {
    let chart: WeeklyRemainingHistoryChart
    let tint: Color

    @State private var hoveredMarkerID: Int?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.045))

                guideLines(in: geometry.size)
                    .stroke(Color.primary.opacity(0.12), style: StrokeStyle(lineWidth: 0.7, dash: [3, 4]))

                chartLine(in: geometry.size)
                    .stroke(tint, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))

                ForEach(chart.dayMarkers) { marker in
                    let markerPoint = point(for: marker.point, in: geometry.size)

                    ZStack {
                        Circle()
                            .fill(marker.id == hoveredMarkerID ? tint : Color.primary.opacity(0.42))
                            .frame(
                                width: marker.id == hoveredMarkerID ? 6 : 4,
                                height: marker.id == hoveredMarkerID ? 6 : 4
                            )
                    }
                    .frame(width: 18, height: 18)
                    .contentShape(Circle())
                    .onHover { isHovering in
                        if isHovering {
                            hoveredMarkerID = marker.id
                        } else if hoveredMarkerID == marker.id {
                            hoveredMarkerID = nil
                        }
                    }
                    .onTapGesture {
                        hoveredMarkerID = marker.id
                    }
                        .position(markerPoint)
                }

                if let latest = chart.latestActualPoint {
                    let latestPoint = point(for: latest, in: geometry.size)

                    Circle()
                        .fill(tint)
                        .frame(width: 5, height: 5)
                        .position(latestPoint)

                    if hoveredMarker?.point != latest {
                        Text("\(UsageMonitorState.percent(latest.remainingPercent))%")
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(tint)
                            .position(
                                WeeklyRemainingHistoryLabelPlacement.valueLabelPosition(
                                    for: latestPoint,
                                    in: geometry.size
                                )
                            )
                    }
                }

                if let hoveredMarker {
                    let markerPoint = point(for: hoveredMarker.point, in: geometry.size)
                    let latestLabelPosition = latestLabelPositionToAvoid(for: hoveredMarker, in: geometry.size)

                    Text(hoveredMarker.hoverLabel)
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .position(
                            WeeklyRemainingHistoryLabelPlacement.hoverLabelPosition(
                                for: markerPoint,
                                avoiding: latestLabelPosition,
                                in: geometry.size
                            )
                        )
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    hoveredMarkerID = nearestMarkerID(to: location, in: geometry.size)
                case .ended:
                    hoveredMarkerID = nil
                }
            }
        }
    }

    private var hoveredMarker: WeeklyRemainingHistoryDayMarker? {
        guard let hoveredMarkerID else { return nil }
        return chart.dayMarkers.first { $0.id == hoveredMarkerID }
    }

    private func guideLines(in size: CGSize) -> Path {
        Path { path in
            for fraction in [0.0, 0.5, 1.0] {
                let y = size.height * CGFloat(fraction)
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }

            for fraction in chart.dayGridPositions {
                let x = size.width * CGFloat(fraction)
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
        }
    }

    private func chartLine(in size: CGSize) -> Path {
        Path { path in
            guard chart.points.count > 1 else { return }

            for (index, point) in chart.points.enumerated() {
                let cgPoint = self.point(for: point, in: size)
                if index == 0 {
                    path.move(to: cgPoint)
                } else {
                    path.addLine(to: cgPoint)
                }
            }
        }
    }

    private func point(for point: WeeklyRemainingHistoryPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width * CGFloat(point.xPosition),
            y: size.height * CGFloat(1 - point.yPosition)
        )
    }

    private func latestLabelPositionToAvoid(
        for hoveredMarker: WeeklyRemainingHistoryDayMarker,
        in size: CGSize
    ) -> CGPoint? {
        guard let latest = chart.latestActualPoint,
              hoveredMarker.point != latest
        else {
            return nil
        }

        return WeeklyRemainingHistoryLabelPlacement.valueLabelPosition(
            for: point(for: latest, in: size),
            in: size
        )
    }

    private func nearestMarkerID(to location: CGPoint, in size: CGSize) -> Int? {
        var nearestID: Int?
        var nearestDistance: CGFloat = 12

        for marker in chart.dayMarkers {
            let markerPoint = point(for: marker.point, in: size)
            let distance = hypot(markerPoint.x - location.x, markerPoint.y - location.y)
            if distance <= nearestDistance {
                nearestID = marker.id
                nearestDistance = distance
            }
        }

        return nearestID
    }
}

struct WeeklyRemainingHistoryLabelPlacement {
    static let valueLabelSize = CGSize(width: 30, height: 12)
    static let hoverLabelSize = CGSize(width: 74, height: 12)
    static let collisionPadding = CGSize(width: 4, height: 3)

    static func valueLabelPosition(for point: CGPoint, in size: CGSize) -> CGPoint {
        let xOffset: CGFloat = point.x > size.width - 34 ? -24 : 24
        let yOffset: CGFloat
        if point.y < 14 {
            yOffset = 12
        } else if point.y > size.height - 14 {
            yOffset = -12
        } else {
            yOffset = -11
        }

        return CGPoint(
            x: min(max(point.x + xOffset, 18), size.width - 18),
            y: min(max(point.y + yOffset, 9), size.height - 9)
        )
    }

    static func hoverLabelPosition(
        for point: CGPoint,
        avoiding latestLabelPosition: CGPoint?,
        in size: CGSize
    ) -> CGPoint {
        let xOffset: CGFloat = point.x > size.width - 46 ? -35 : 35
        let yOffsets: [CGFloat] = point.y < 16 ? [13, -13, 25, -25] : [-13, 13, -25, 25]
        let xOffsets: [CGFloat] = [xOffset, -xOffset]

        let candidates = xOffsets.flatMap { xOffset in
            yOffsets.map { yOffset in
                clampedPosition(
                    CGPoint(x: point.x + xOffset, y: point.y + yOffset),
                    in: size,
                    horizontalMargin: 22,
                    verticalMargin: 9
                )
            }
        }

        guard let latestLabelPosition else {
            return candidates[0]
        }

        let latestRect = labelRect(center: latestLabelPosition, size: valueLabelSize)
            .insetBy(dx: -collisionPadding.width, dy: -collisionPadding.height)
        if let clearCandidate = candidates.first(where: {
            !labelRect(center: $0, size: hoverLabelSize).intersects(latestRect)
        }) {
            return clearCandidate
        }

        return candidates.max {
            distanceSquared(from: $0, to: latestLabelPosition) <
                distanceSquared(from: $1, to: latestLabelPosition)
        } ?? candidates[0]
    }

    static func labelRect(center: CGPoint, size: CGSize) -> CGRect {
        CGRect(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private static func clampedPosition(
        _ point: CGPoint,
        in size: CGSize,
        horizontalMargin: CGFloat,
        verticalMargin: CGFloat
    ) -> CGPoint {
        CGPoint(
            x: min(max(point.x, horizontalMargin), size.width - horizontalMargin),
            y: min(max(point.y, verticalMargin), size.height - verticalMargin)
        )
    }

    private static func distanceSquared(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return dx * dx + dy * dy
    }
}

struct WeeklyRemainingHistoryChart: Equatable {
    let points: [WeeklyRemainingHistoryPoint]
    let dayGridPositions: [Double]
    let dayMarkers: [WeeklyRemainingHistoryDayMarker]
    let actualSampleCount: Int
    let resetStartAt: Int?
    let resetsAt: Int?
    let resetStartLabel: String
    let resetEndLabel: String

    init(
        history: CodexUsageWeeklyHistory,
        weeklyWindow: UsageWindowReport?,
        currentSample: CodexUsageWeeklyHistorySample? = nil,
        calendar: Calendar = .current
    ) {
        guard let weeklyWindow,
              let resetsAt = weeklyWindow.resetsAt
        else {
            self.points = []
            self.dayGridPositions = []
            self.dayMarkers = []
            self.actualSampleCount = 0
            self.resetStartAt = nil
            self.resetsAt = nil
            self.resetStartLabel = "시작"
            self.resetEndLabel = "종료"
            return
        }

        let durationMins = weeklyWindow.windowDurationMins ?? 10_080
        let durationSeconds = max(durationMins, 1) * 60
        let resetStartAt = resetsAt - durationSeconds
        var samples = history.samples.filter {
            $0.resetsAt == resetsAt &&
                $0.recordedAt >= resetStartAt &&
                $0.recordedAt <= resetsAt
        }

        if let currentSample,
           currentSample.resetsAt == resetsAt,
           currentSample.recordedAt >= resetStartAt,
           currentSample.recordedAt <= resetsAt,
           !samples.contains(where: { $0.recordedAt == currentSample.recordedAt }) {
            samples.append(currentSample)
        }

        samples.sort { $0.recordedAt < $1.recordedAt }

        let dayGridPositions = Self.dayGridPositions(durationSeconds: durationSeconds)
        let actualPoints = samples.map {
            WeeklyRemainingHistoryPoint(
                recordedAt: $0.recordedAt,
                remainingPercent: $0.remainingPercent,
                xPosition: Self.xPosition(
                    recordedAt: $0.recordedAt,
                    resetStartAt: resetStartAt,
                    durationSeconds: durationSeconds
                ),
                isResetAnchor: false
            )
        }

        self.points = [
            WeeklyRemainingHistoryPoint(
                recordedAt: resetStartAt,
                remainingPercent: 100,
                xPosition: 0,
                isResetAnchor: true
            )
        ] + actualPoints
        self.dayGridPositions = dayGridPositions
        self.dayMarkers = Self.dayMarkers(
            from: actualPoints,
            resetStartAt: resetStartAt,
            durationSeconds: durationSeconds,
            calendar: calendar
        )
        self.actualSampleCount = actualPoints.count
        self.resetStartAt = resetStartAt
        self.resetsAt = resetsAt
        self.resetStartLabel = Self.resetDayLabel(timestamp: resetStartAt, calendar: calendar)
        self.resetEndLabel = Self.resetDayLabel(timestamp: resetsAt, calendar: calendar)
    }

    var latestActualPoint: WeeklyRemainingHistoryPoint? {
        points.last { !$0.isResetAnchor }
    }

    var summaryText: String {
        guard let latestActualPoint else {
            return resetsAt == nil ? "초기화 시각 필요" : "샘플 대기"
        }
        return "\(UsageMonitorState.percent(latestActualPoint.remainingPercent))% 남음"
    }

    var accessibilityValue: String {
        guard let latestActualPoint else {
            return summaryText
        }
        return "최근 주간 잔여량 \(UsageMonitorState.percent(latestActualPoint.remainingPercent))%, 샘플 \(actualSampleCount)개"
    }

    private static func xPosition(
        recordedAt: Int,
        resetStartAt: Int,
        durationSeconds: Int
    ) -> Double {
        let elapsed = Double(recordedAt - resetStartAt)
        return min(max(elapsed / Double(durationSeconds), 0), 1)
    }

    private static func dayGridPositions(durationSeconds: Int) -> [Double] {
        let daySeconds = 86_400
        let dayCount = max(1, Int(ceil(Double(durationSeconds) / Double(daySeconds))))

        return (0...dayCount).map {
            min(Double($0 * daySeconds) / Double(durationSeconds), 1)
        }
    }

    private static func dayMarkers(
        from actualPoints: [WeeklyRemainingHistoryPoint],
        resetStartAt: Int,
        durationSeconds: Int,
        calendar: Calendar
    ) -> [WeeklyRemainingHistoryDayMarker] {
        let daySeconds = 86_400
        let dayCount = max(1, Int(ceil(Double(durationSeconds) / Double(daySeconds))))
        let maxDayIndex = max(0, dayCount - 1)
        var latestByDay: [Int: WeeklyRemainingHistoryPoint] = [:]

        for point in actualPoints {
            let elapsed = min(max(point.recordedAt - resetStartAt, 0), max(durationSeconds - 1, 0))
            let dayIndex = min(max(Int(Double(elapsed) / Double(daySeconds)), 0), maxDayIndex)
            latestByDay[dayIndex] = point
        }

        return latestByDay.keys.sorted().compactMap { dayIndex in
            guard let point = latestByDay[dayIndex] else { return nil }
            let dayLabel = resetDayLabel(timestamp: point.recordedAt, calendar: calendar)
            return WeeklyRemainingHistoryDayMarker(
                id: dayIndex,
                point: point,
                hoverLabel: "\(dayLabel) · \(UsageMonitorState.percent(point.remainingPercent))%"
            )
        }
    }

    private static func resetDayLabel(timestamp: Int, calendar inputCalendar: Calendar) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let components = inputCalendar.dateComponents([.month, .day, .weekday], from: date)
        let month = components.month ?? 0
        let day = components.day ?? 0
        let weekday = weekdaySymbol(for: components.weekday)
        return "\(month)/\(day) \(weekday)"
    }

    private static func weekdaySymbol(for weekday: Int?) -> String {
        let symbols = ["일", "월", "화", "수", "목", "금", "토"]
        guard let weekday, (1...7).contains(weekday) else { return "?" }
        return symbols[weekday - 1]
    }
}

struct WeeklyRemainingHistoryPoint: Equatable {
    let recordedAt: Int
    let remainingPercent: Double
    let xPosition: Double
    let isResetAnchor: Bool

    var yPosition: Double {
        min(max(remainingPercent / 100, 0), 1)
    }
}

struct WeeklyRemainingHistoryDayMarker: Equatable, Identifiable {
    let id: Int
    let point: WeeklyRemainingHistoryPoint
    let hoverLabel: String
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

            RemainingUsageBar(value: progressValue, tint: tint)
                .accessibilityLabel("\(title) 남은 사용량")
                .accessibilityValue(summary)

        }
    }

    private var summary: String {
        guard let window else { return "확인 불가" }
        return "\(UsageMonitorState.percent(window.usedPercent))% 사용 / \(UsageMonitorState.percent(window.remainingPercent))% 남음"
    }

    private var progressValue: Double {
        min(max((window?.remainingPercent ?? 0) / 100, 0), 1)
    }

    private var tint: Color {
        switch window?.remainingPercent ?? 0 {
        case ..<10:
            .red
        case 10..<30:
            .orange
        case 30..<60:
            .yellow
        default:
            .green
        }
    }
}

private struct RemainingUsageBar: View {
    let value: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.12))
                RoundedRectangle(cornerRadius: 4)
                    .fill(tint)
                    .frame(width: fillWidth(in: proxy.size.width))
                    .opacity(value > 0 ? 1 : 0)
            }
        }
        .frame(height: 8)
    }

    private func fillWidth(in totalWidth: CGFloat) -> CGFloat {
        let clamped = min(max(value, 0), 1)
        guard clamped > 0 else { return 0 }
        return max(4, totalWidth * clamped)
    }
}
