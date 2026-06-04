import AppKit
import MacDogPrivilegedHelperSupport
import SwiftUI

struct SettingsPanel: View {
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
