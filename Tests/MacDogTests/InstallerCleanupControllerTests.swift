import XCTest
@testable import MacDog

final class InstallerCleanupControllerTests: XCTestCase {
    func testCleanupPlanIncludesOnlyMacDogInstallerArtifacts() throws {
        let home = try temporaryDirectory()
        let downloads = home.appendingPathComponent("Downloads", isDirectory: true)
        let desktop = home.appendingPathComponent("Desktop", isDirectory: true)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: desktop, withIntermediateDirectories: true)

        let expectedFiles = [
            downloads.appendingPathComponent("MacDog-1.0.0.dmg"),
            downloads.appendingPathComponent("MacDog-1.0.0.dmg.sha256"),
            desktop.appendingPathComponent("MacDog-1.0.0-release-notes.md")
        ]
        let ignoredFiles = [
            downloads.appendingPathComponent("Other-1.0.0.dmg"),
            downloads.appendingPathComponent("MacDog-preview.png"),
            desktop.appendingPathComponent("MacDog-notes.txt")
        ]

        for file in expectedFiles + ignoredFiles {
            try Data(file.lastPathComponent.utf8).write(to: file)
        }

        let controller = InstallerCleanupController(homeDirectory: home)
        let plan = controller.cleanupPlan()

        XCTAssertEqual(
            Set(plan.downloadedInstallerFiles.map(\.lastPathComponent)),
            Set(expectedFiles.map(\.lastPathComponent))
        )
        XCTAssertTrue(
            ignoredFiles.allSatisfy { ignored in
                !plan.downloadedInstallerFiles.contains { $0.lastPathComponent == ignored.lastPathComponent }
            }
        )
    }

    func testCleanupPlanIncludesOnlyMountedMacDogInstallerVolumes() throws {
        let root = try temporaryDirectory()
        let validVolume = root.appendingPathComponent("MacDog 1.0.0", isDirectory: true)
        let invalidVolume = root.appendingPathComponent("MacDog Broken", isDirectory: true)
        let otherVolume = root.appendingPathComponent("Other 1.0.0", isDirectory: true)

        try FileManager.default.createDirectory(
            at: validVolume.appendingPathComponent("MacDog.app", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: invalidVolume.appendingPathComponent("Applications", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: otherVolume.appendingPathComponent("MacDog.app", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: validVolume.appendingPathComponent("Applications", isDirectory: true),
            withIntermediateDirectories: true
        )

        let controller = InstallerCleanupController(
            homeDirectory: root,
            mountedVolumeProvider: { [validVolume, invalidVolume, otherVolume] }
        )

        XCTAssertEqual(controller.cleanupPlan().mountedInstallerVolumes, [validVolume])
    }

    func testCleanupRemovesDownloadsAndDetachesVolumes() throws {
        let home = try temporaryDirectory()
        let downloads = home.appendingPathComponent("Downloads", isDirectory: true)
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        let installer = downloads.appendingPathComponent("MacDog-1.0.0.dmg")
        try Data("installer".utf8).write(to: installer)
        let volume = home.appendingPathComponent("MacDog 1.0.0", isDirectory: true)
        var detachedVolumes: [URL] = []
        let controller = InstallerCleanupController(
            homeDirectory: home,
            mountedVolumeProvider: { [volume] },
            detachVolumeHandler: { detachedVolumes.append($0) }
        )
        let plan = InstallerCleanupPlan(
            mountedInstallerVolumes: [volume],
            downloadedInstallerFiles: [installer]
        )

        try controller.cleanup(plan)

        XCTAssertFalse(FileManager.default.fileExists(atPath: installer.path))
        XCTAssertEqual(detachedVolumes, [volume])
    }

    func testLegacyDismissedFlagDoesNotSuppressNewInstallerArtifacts() throws {
        let defaults = try temporaryDefaults()
        defaults.set(true, forKey: InstallerCleanupController.promptDismissedKey)

        let plan = InstallerCleanupPlan(
            mountedInstallerVolumes: [
                URL(fileURLWithPath: "/Volumes/MacDog 1.3.0", isDirectory: true)
            ],
            downloadedInstallerFiles: []
        )

        XCTAssertTrue(InstallerCleanupController.shouldShowPrompt(for: plan, defaults: defaults))
    }

    func testPromptDismissalIsScopedToInstallerArtifactSignature() throws {
        let defaults = try temporaryDefaults()
        let previousPlan = InstallerCleanupPlan(
            mountedInstallerVolumes: [
                URL(fileURLWithPath: "/Volumes/MacDog 1.2.3", isDirectory: true)
            ],
            downloadedInstallerFiles: [
                URL(fileURLWithPath: "/Users/test/Downloads/MacDog-1.2.3.dmg")
            ]
        )
        let currentPlan = InstallerCleanupPlan(
            mountedInstallerVolumes: [
                URL(fileURLWithPath: "/Volumes/MacDog 1.3.0", isDirectory: true)
            ],
            downloadedInstallerFiles: [
                URL(fileURLWithPath: "/Users/test/Downloads/MacDog-1.3.0.dmg")
            ]
        )

        InstallerCleanupController.recordPromptDismissed(for: previousPlan, defaults: defaults)

        XCTAssertFalse(InstallerCleanupController.shouldShowPrompt(for: previousPlan, defaults: defaults))
        XCTAssertTrue(InstallerCleanupController.shouldShowPrompt(for: currentPlan, defaults: defaults))
    }

    private func temporaryDirectory() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("MacDogInstallerCleanupTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func temporaryDefaults() throws -> UserDefaults {
        let suiteName = "MacDogInstallerCleanupTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
