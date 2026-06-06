import AppKit
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

        XCTAssertEqual(MenuBarIconRenderer.imageSize.width, 32)
        XCTAssertEqual(MenuBarIconRenderer.imageSize.height, 21)
        XCTAssertEqual(image.size.width, MenuBarIconRenderer.imageSize.width)
        XCTAssertEqual(image.size.height, MenuBarIconRenderer.imageSize.height)
        XCTAssertFalse(image.isTemplate)
    }

    func testMenuBarIconRendererFillsMenuBarWithVisibleCharacterPixels() throws {
        let renderer = MenuBarIconRenderer()

        for frame in 0..<MenuBarIconRenderer.frameCount {
            let image = renderer.image(frame: frame, phase: .calm)
            let visibleRect = try XCTUnwrap(visibleContentRect(in: image), "frame \(frame) has visible menu bar pixels")

            XCTAssertGreaterThanOrEqual(visibleRect.width, 20, "frame \(frame) visible width")
            XCTAssertGreaterThanOrEqual(visibleRect.height, 14, "frame \(frame) visible height")
            XCTAssertLessThanOrEqual(visibleRect.height, MenuBarIconRenderer.imageSize.height, "frame \(frame) visible height")
            XCTAssertGreaterThan(visibleRect.minY, 0, "frame \(frame) top padding")
            XCTAssertLessThan(visibleRect.maxY, image.size.height, "frame \(frame) bottom padding")
        }
    }

    func testMenuBarIconRendererKeepsFramePositionStableAcrossAnimation() throws {
        let renderer = MenuBarIconRenderer()
        let visibleRects = try (0..<MenuBarIconRenderer.frameCount).map { frame in
            let image = renderer.image(frame: frame, phase: .calm)
            return try XCTUnwrap(visibleContentRect(in: image), "frame \(frame) has visible menu bar pixels")
        }
        let heights = visibleRects.map(\.height)
        let centerXs = visibleRects.map(\.midX)
        let centerYs = visibleRects.map(\.midY)

        XCTAssertLessThanOrEqual((centerXs.max() ?? 0) - (centerXs.min() ?? 0), 1.5, "visible horizontal center range")
        XCTAssertLessThanOrEqual((heights.max() ?? 0) - (heights.min() ?? 0), 3, "visible height range")
        XCTAssertLessThanOrEqual((centerYs.max() ?? 0) - (centerYs.min() ?? 0), 3, "visible vertical center range")
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

    private func visibleContentRect(in image: NSImage) -> NSRect? {
        guard
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff)
        else {
            return nil
        }

        var minX = bitmap.pixelsWide
        var minY = bitmap.pixelsHigh
        var maxX = -1
        var maxY = -1

        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard let color = bitmap.colorAt(x: x, y: y), color.alphaComponent > 0.02 else {
                    continue
                }
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY else {
            return nil
        }

        let scaleX = image.size.width / CGFloat(bitmap.pixelsWide)
        let scaleY = image.size.height / CGFloat(bitmap.pixelsHigh)

        return NSRect(
            x: CGFloat(minX) * scaleX,
            y: CGFloat(minY) * scaleY,
            width: CGFloat(maxX - minX + 1) * scaleX,
            height: CGFloat(maxY - minY + 1) * scaleY
        )
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
