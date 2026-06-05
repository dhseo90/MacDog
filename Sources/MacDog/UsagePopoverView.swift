import SwiftUI

struct UsagePopoverView: View {
    let state: UsageMonitorState
    let onPreferencesChanged: () -> Void
    let onAction: (PetAction) -> Void
    let notificationAuthorizationClient: any UsageNotificationAuthorizationProviding

    @AppStorage(RunnerPreferences.popoverModuleKey) private var selectedModuleRaw = MacDogPopoverModule.codex.rawValue

    init(
        state: UsageMonitorState,
        onPreferencesChanged: @escaping () -> Void = {},
        onAction: @escaping (PetAction) -> Void = { _ in },
        notificationAuthorizationClient: any UsageNotificationAuthorizationProviding = UsageNotificationAuthorizationClient()
    ) {
        self.state = state
        self.onPreferencesChanged = onPreferencesChanged
        self.onAction = onAction
        self.notificationAuthorizationClient = notificationAuthorizationClient
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
            CodexUsagePanel(state: state)
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
                onPreferencesChanged: onPreferencesChanged,
                notificationAuthorizationClient: notificationAuthorizationClient
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

}
