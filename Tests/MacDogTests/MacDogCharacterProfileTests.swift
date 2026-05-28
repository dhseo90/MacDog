import XCTest
@testable import MacDog

final class MacDogCharacterProfileTests: XCTestCase {
    func testCodexPupConnectsRunnerDesktopPetAndTabArtwork() {
        let profile = MacDogCharacterProfile.codexPup

        XCTAssertEqual(profile.id, "codex-pup")
        XCTAssertEqual(profile.displayName, "Codex Pup")
        XCTAssertEqual(profile.runner.resourceDirectory, "Runner")
        XCTAssertEqual(profile.runner.framePrefix, "pup-runner")
        XCTAssertEqual(profile.runner.frameCount, RunnerIconRenderer.frameCount)
        XCTAssertEqual(profile.desktopPet.resourceDirectory, "DesktopPet")
        XCTAssertEqual(profile.popoverTabs.resourceDirectory, "PopoverTabs")
    }

    func testCodexPupDefinesEveryDesktopPose() {
        let profile = MacDogCharacterProfile.codexPup

        for pose in DesktopPetPose.allCases {
            let asset = profile.desktopPet.asset(for: pose)
            XCTAssertEqual(asset.resourcePrefix, pose.resourcePrefix)
            XCTAssertEqual(asset.frameCount, pose.frameCount)
        }
    }

    func testCodexPupDefinesEveryPopoverTabArtwork() {
        let profile = MacDogCharacterProfile.codexPup

        for module in MacDogPopoverModule.allCases {
            let asset = profile.popoverTabs.artwork(for: module)
            XCTAssertEqual(asset.resourceName, module.artworkName)
            XCTAssertEqual(asset.systemImage, module.systemImage)
        }
    }
}
