import XCTest
@testable import MacDogPrivilegedHelperSupport

final class PrivilegedHelperInstallStateTests: XCTestCase {
    func testInstallSnapshotStatus() {
        XCTAssertEqual(
            PrivilegedHelperInstallSnapshot(helperToolExists: false, launchDaemonExists: false).status,
            .missing
        )
        XCTAssertEqual(
            PrivilegedHelperInstallSnapshot(helperToolExists: true, launchDaemonExists: false).status,
            .partial
        )
        XCTAssertEqual(
            PrivilegedHelperInstallSnapshot(helperToolExists: false, launchDaemonExists: true).status,
            .partial
        )
        XCTAssertEqual(
            PrivilegedHelperInstallSnapshot(helperToolExists: true, launchDaemonExists: true).status,
            .installed
        )
    }

    func testStateReaderChecksExpectedInstallPaths() {
        let plan = PrivilegedHelperInstallPlan.current
        let reader = PrivilegedHelperInstallStateReader(
            plan: plan,
            fileChecker: RecordingFileChecker(existingPaths: [
                plan.helperToolDestination
            ])
        )

        let snapshot = reader.snapshot()

        XCTAssertEqual(snapshot.status, .partial)
        XCTAssertTrue(snapshot.helperToolExists)
        XCTAssertFalse(snapshot.launchDaemonExists)
    }
}

private struct RecordingFileChecker: PrivilegedHelperFileChecking, Sendable {
    let existingPaths: Set<String>

    func fileExists(atPath path: String) -> Bool {
        existingPaths.contains(path)
    }
}
