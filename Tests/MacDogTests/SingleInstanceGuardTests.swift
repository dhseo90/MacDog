import XCTest
@testable import MacDog

final class SingleInstanceGuardTests: XCTestCase {
    func testFindsExistingApplicationWithSameBundleIdentifier() {
        let duplicate = SingleInstanceGuard.duplicateApplication(
            in: [
                RunningApplicationSnapshot(
                    processIdentifier: 100,
                    bundleIdentifier: SingleInstanceGuard.appBundleIdentifier,
                    localizedName: "MacDog"
                ),
                RunningApplicationSnapshot(
                    processIdentifier: 200,
                    bundleIdentifier: "com.example.Other",
                    localizedName: "Other"
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
                    localizedName: "MacDog"
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
                    localizedName: "MacDog"
                )
            ],
            currentProcessIdentifier: 300
        )

        XCTAssertNil(duplicate)
    }
}
