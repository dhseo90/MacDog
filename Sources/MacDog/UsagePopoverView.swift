import SwiftUI

struct UsagePopoverView: View {
    let state: UsageMonitorState
    let onPreferencesChanged: () -> Void
    let onAction: (PetAction) -> Void
    let notificationAuthorizationClient: any UsageNotificationAuthorizationProviding
    let now: Date

    @AppStorage(RunnerPreferences.popoverModuleKey) private var selectedModuleRaw = MacDogPopoverModule.codex.rawValue

    init(
        state: UsageMonitorState,
        onPreferencesChanged: @escaping () -> Void = {},
        onAction: @escaping (PetAction) -> Void = { _ in },
        notificationAuthorizationClient: any UsageNotificationAuthorizationProviding = UsageNotificationAuthorizationClient(),
        now: Date = Date()
    ) {
        self.state = state
        self.onPreferencesChanged = onPreferencesChanged
        self.onAction = onAction
        self.notificationAuthorizationClient = notificationAuthorizationClient
        self.now = now
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
            Text(selectedModuleTitle)
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
        if usesScrollableSelectedContent {
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

    private var usesScrollableSelectedContent: Bool {
        selectedModule.usesScrollableContent ||
            (selectedModule == .codex && state.usageProviderMode == .claude)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedModule {
        case .codex:
            usageProviderContent
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
            return state.usageProviderMode == .claude
                ? state.claudeUsagePreview.statusTitle(now: now)
                : state.codexPhase.statusLabel
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

    private var selectedModuleTitle: String {
        if selectedModule == .codex, state.usageProviderMode == .claude {
            return "Claude 사용량"
        }
        return selectedModule.title
    }

    @ViewBuilder
    private var usageProviderContent: some View {
        if state.usageProviderMode == .claude {
            ClaudeUsagePreviewPanel(preview: state.claudeUsagePreview, now: now)
        } else {
            CodexUsagePanel(state: state)
        }
    }

}
