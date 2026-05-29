import XCTest
@testable import MacDog

final class SingleInstanceGuardTests: XCTestCase {
    func testFindsExistingApplicationWithSameBundleIdentifier() {
        let duplicate = SingleInstanceGuard.duplicateApplication(
            in: [
                RunningApplicationSnapshot(
                    processIdentifier: 100,
                    bundleIdentifier: SingleInstanceGuard.appBundleIdentifier,
                    localizedName: "MacDog",
                    bundleURLPath: "/Applications/MacDog.app",
                    executableURLPath: "/Applications/MacDog.app/Contents/MacOS/MacDog"
                ),
                RunningApplicationSnapshot(
                    processIdentifier: 200,
                    bundleIdentifier: "com.example.Other",
                    localizedName: "Other",
                    bundleURLPath: "/Applications/Other.app",
                    executableURLPath: "/Applications/Other.app/Contents/MacOS/Other"
                )
            ],
            currentProcessIdentifier: 300
        )

        XCTAssertEqual(duplicate?.processIdentifier, 100)
    }

    func testIgnoresCurrentProcess() {
        let duplicate = SingleInstanceGuard.duplicateApplication(
            in: [
                RunningApplicationSnapshot(
                    processIdentifier: 300,
                    bundleIdentifier: SingleInstanceGuard.appBundleIdentifier,
                    localizedName: "MacDog",
                    bundleURLPath: "/Applications/MacDog.app",
                    executableURLPath: "/Applications/MacDog.app/Contents/MacOS/MacDog"
                )
            ],
            currentProcessIdentifier: 300
        )

        XCTAssertNil(duplicate)
    }

    func testIgnoresDifferentBundleIdentifier() {
        let duplicate = SingleInstanceGuard.duplicateApplication(
            in: [
                RunningApplicationSnapshot(
                    processIdentifier: 100,
                    bundleIdentifier: "com.example.Other",
                    localizedName: "Other",
                    bundleURLPath: "/Applications/Other.app",
                    executableURLPath: "/Applications/Other.app/Contents/MacOS/Other"
                )
            ],
            currentProcessIdentifier: 300
        )

        XCTAssertNil(duplicate)
    }

    func testTreatsMacDogProcessWithoutBundleIdentifierAsDuplicate() {
        let duplicate = SingleInstanceGuard.duplicateApplication(
            in: [
                RunningApplicationSnapshot(
                    processIdentifier: 100,
                    bundleIdentifier: nil,
                    localizedName: "MacDog",
                    bundleURLPath: nil,
                    executableURLPath: "/tmp/MacDog"
                )
            ],
            currentProcessIdentifier: 300
        )

        XCTAssertEqual(duplicate?.processIdentifier, 100)
    }

    func testLaunchDecisionTerminatesCurrentWhenSameBundleIsAlreadyRunning() {
        let decision = SingleInstanceGuard.launchDecision(
            applications: [
                RunningApplicationSnapshot(
                    processIdentifier: 100,
                    bundleIdentifier: SingleInstanceGuard.appBundleIdentifier,
                    localizedName: "MacDog",
                    bundleURLPath: "/Users/dhseo/Applications/MacDog.app",
                    executableURLPath: "/Users/dhseo/Applications/MacDog.app/Contents/MacOS/MacDog"
                )
            ],
            currentProcessIdentifier: 300,
            currentBundlePath: "/Users/dhseo/Applications/MacDog.app"
        )

        XCTAssertEqual(decision, .terminateCurrent(activateProcessIdentifier: 100))
    }

    func testLaunchDecisionTerminatesDuplicateWhenNewBundlePathIsDifferent() {
        let decision = SingleInstanceGuard.launchDecision(
            applications: [
                RunningApplicationSnapshot(
                    processIdentifier: 100,
                    bundleIdentifier: SingleInstanceGuard.appBundleIdentifier,
                    localizedName: "MacDog",
                    bundleURLPath: "/Users/dhseo/Applications/MacDog.app",
                    executableURLPath: "/Users/dhseo/Applications/MacDog.app/Contents/MacOS/MacDog"
                )
            ],
            currentProcessIdentifier: 300,
            currentBundlePath: "/Users/dhseo/Desktop/workspace/MacDog/dist/MacDog.app"
        )

        XCTAssertEqual(decision, .terminateDuplicate(processIdentifier: 100))
    }

    func testParsesProcessIdentifiersFromPgrepOutput() {
        XCTAssertEqual(
            SingleInstanceGuard.processIdentifiers(from: "100\n 200 \nnot-a-pid\n"),
            [100, 200]
        )
    }

    func testShouldTerminateCurrentWhenAnotherMacDogProcessExists() {
        XCTAssertTrue(SingleInstanceGuard.shouldTerminateCurrentInstance(
            currentProcessIdentifier: 200,
            processIdentifierProvider: { [100, 200] }
        ))
    }

    func testShouldContinueWhenOnlyCurrentMacDogProcessExists() {
        XCTAssertFalse(SingleInstanceGuard.shouldTerminateCurrentInstance(
            currentProcessIdentifier: 200,
            processIdentifierProvider: { [200] }
        ))
    }
}
