import XCTest
@testable import MacDog

final class MacDogCharacterProfileTests: XCTestCase {
    func testCodexPupConnectsMenuBarImageDesktopPetAndTabArtwork() {
        let profile = MacDogCharacterProfile.codexPup

        XCTAssertEqual(profile.id, "codex-pup")
        XCTAssertEqual(profile.displayName, "Codex Pup")
        XCTAssertEqual(profile.menuBarImage.sourcePose, .runRight)
        XCTAssertEqual(
            profile.desktopPet.asset(for: profile.menuBarImage.sourcePose).frameCount,
            MenuBarIconRenderer.frameCount
        )
        XCTAssertEqual(profile.desktopPet.resourceDirectory, "DesktopPet")
        XCTAssertEqual(profile.popoverTabs.resourceDirectory, "PopoverTabs")
    }

    func testMenuBarIconRendererCreatesImageFromCurrentCharacterFrames() {
        let renderer = MenuBarIconRenderer()
        let image = renderer.image(frame: 0, phase: .calm)

        XCTAssertEqual(image.size.width, 28)
        XCTAssertEqual(image.size.height, 24)
        XCTAssertFalse(image.isTemplate)
    }

    func testCodexPupDefinesEveryDesktopPose() {
        let profile = MacDogCharacterProfile.codexPup

        for pose in DesktopPetPose.allCases {
            let asset = profile.desktopPet.asset(for: pose)
            XCTAssertEqual(asset.resourcePrefix, pose.resourcePrefix)
            XCTAssertEqual(asset.frameCount, pose.frameCount)
        }
    }

    func testCodexPupDefinesEveryPopoverTabArtwork() throws {
        let profile = MacDogCharacterProfile.codexPup
        let expectedSources: [MacDogPopoverModule: (pose: DesktopPetPose, frame: Int)] = [
            .codex: (.idleFront, 0),
            .mac: (.runRight, 2),
            .sleep: (.rest, 0),
            .battery: (.alert, 1),
            .settings: (.idleSide, 0)
        ]

        for module in MacDogPopoverModule.allCases {
            let asset = profile.popoverTabs.artwork(for: module)
            let expectedSource = try XCTUnwrap(expectedSources[module])
            XCTAssertEqual(asset.resourceName, module.artworkName)
            XCTAssertEqual(asset.systemImage, module.systemImage)
            XCTAssertEqual(asset.sourcePose, expectedSource.pose)
            XCTAssertEqual(asset.sourceFrameIndex, expectedSource.frame)
            XCTAssertEqual(asset.badgeSystemImage, module.systemImage)
        }
    }

    func testCodexPupTabArtworkManifestMatchesProfile() throws {
        let profile = MacDogCharacterProfile.codexPup
        let manifest = try loadCodexPupTabArtworkManifest()

        XCTAssertEqual(manifest.characterId, profile.id)
        XCTAssertEqual(manifest.desktopSource.resourceDirectory, profile.desktopPet.resourceDirectory)
        XCTAssertEqual(manifest.desktopSource.sourcePose, "idleFront")
        XCTAssertEqual(manifest.desktopSource.resourcePrefix, profile.desktopPet.asset(for: .idleFront).resourcePrefix)
        XCTAssertEqual(manifest.desktopSource.sourceFrameIndex, 0)
        XCTAssertEqual(manifest.outputDirectory, profile.popoverTabs.resourceDirectory)

        for module in MacDogPopoverModule.allCases {
            let profileArtwork = profile.popoverTabs.artwork(for: module)
            let manifestArtwork = try XCTUnwrap(manifest.tabs.first { $0.module == module.rawValue })
            XCTAssertEqual(manifestArtwork.resourceName, profileArtwork.resourceName)
            XCTAssertEqual(manifestArtwork.sourcePose, String(describing: profileArtwork.sourcePose))
            XCTAssertEqual(manifestArtwork.resourcePrefix, profile.desktopPet.asset(for: profileArtwork.sourcePose).resourcePrefix)
            XCTAssertEqual(manifestArtwork.sourceFrameIndex, profileArtwork.sourceFrameIndex)
            XCTAssertEqual(manifestArtwork.topicSymbol, profileArtwork.badgeSystemImage)
        }
    }

    private func loadCodexPupTabArtworkManifest() throws -> TabArtworkManifestFixture {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent("MacDog", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("CharacterProfiles", isDirectory: true)
            .appendingPathComponent("codex-pup-tab-art.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(TabArtworkManifestFixture.self, from: data)
    }
}

private struct TabArtworkManifestFixture: Decodable {
    let characterId: String
    let desktopSource: TabArtworkDesktopSourceFixture
    let outputDirectory: String
    let tabs: [TabArtworkFixture]
}

private struct TabArtworkDesktopSourceFixture: Decodable {
    let resourceDirectory: String
    let sourcePose: String
    let resourcePrefix: String
    let sourceFrameIndex: Int
}

private struct TabArtworkFixture: Decodable {
    let module: String
    let resourceName: String
    let sourcePose: String
    let resourcePrefix: String
    let sourceFrameIndex: Int
    let topicSymbol: String
}
