struct MacDogCharacterProfile: Equatable {
    static let codexPup = MacDogCharacterProfile(
        id: "codex-pup",
        displayName: "Codex Pup",
        runner: RunnerAssetCatalog(
            resourceDirectory: "Runner",
            framePrefix: "pup-runner",
            frameCount: 8
        ),
        desktopPet: DesktopPetAssetCatalog(
            resourceDirectory: "DesktopPet",
            poses: [
                .runRight: DesktopPetPoseAsset(resourcePrefix: "pup-run-right", frameCount: 8),
                .runUp: DesktopPetPoseAsset(resourcePrefix: "pup-run-up", frameCount: 8),
                .runDown: DesktopPetPoseAsset(resourcePrefix: "pup-run-down", frameCount: 8),
                .idleFront: DesktopPetPoseAsset(resourcePrefix: "pup-idle-front", frameCount: 4),
                .idleSide: DesktopPetPoseAsset(resourcePrefix: "pup-idle-side", frameCount: 4),
                .rest: DesktopPetPoseAsset(resourcePrefix: "pup-rest", frameCount: 4),
                .alert: DesktopPetPoseAsset(resourcePrefix: "pup-alert", frameCount: 4)
            ]
        ),
        popoverTabs: PopoverTabAssetCatalog(
            resourceDirectory: "PopoverTabs",
            artwork: [
                .codex: PopoverTabArtworkAsset(
                    resourceName: "codex-tab",
                    systemImage: "chevron.left.forwardslash.chevron.right",
                    sourcePose: .idleFront,
                    sourceFrameIndex: 0,
                    badgeSystemImage: "chevron.left.forwardslash.chevron.right"
                ),
                .mac: PopoverTabArtworkAsset(
                    resourceName: "mac-tab",
                    systemImage: "cpu",
                    sourcePose: .idleFront,
                    sourceFrameIndex: 0,
                    badgeSystemImage: "cpu"
                ),
                .sleep: PopoverTabArtworkAsset(
                    resourceName: "sleep-tab",
                    systemImage: "moon.fill",
                    sourcePose: .idleFront,
                    sourceFrameIndex: 0,
                    badgeSystemImage: "moon.fill"
                ),
                .battery: PopoverTabArtworkAsset(
                    resourceName: "battery-tab",
                    systemImage: "battery.100percent",
                    sourcePose: .idleFront,
                    sourceFrameIndex: 0,
                    badgeSystemImage: "battery.100percent"
                )
            ]
        )
    )

    let id: String
    let displayName: String
    let runner: RunnerAssetCatalog
    let desktopPet: DesktopPetAssetCatalog
    let popoverTabs: PopoverTabAssetCatalog
}

struct RunnerAssetCatalog: Equatable {
    let resourceDirectory: String
    let framePrefix: String
    let frameCount: Int
}

struct DesktopPetAssetCatalog: Equatable {
    let resourceDirectory: String
    let poses: [DesktopPetPose: DesktopPetPoseAsset]

    func asset(for pose: DesktopPetPose) -> DesktopPetPoseAsset {
        guard let asset = poses[pose] else {
            preconditionFailure("Missing desktop pet asset for pose: \(pose)")
        }
        return asset
    }
}

struct DesktopPetPoseAsset: Equatable {
    let resourcePrefix: String
    let frameCount: Int
}

struct PopoverTabAssetCatalog: Equatable {
    let resourceDirectory: String
    let artwork: [MacDogPopoverModule: PopoverTabArtworkAsset]

    func artwork(for module: MacDogPopoverModule) -> PopoverTabArtworkAsset {
        guard let asset = artwork[module] else {
            preconditionFailure("Missing popover tab artwork for module: \(module)")
        }
        return asset
    }
}

struct PopoverTabArtworkAsset: Equatable {
    let resourceName: String
    let systemImage: String
    let sourcePose: DesktopPetPose
    let sourceFrameIndex: Int
    let badgeSystemImage: String
}
