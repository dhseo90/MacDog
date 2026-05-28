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

    func testInstallSnapshotGuidanceExplainsUserAction() {
        let missing = PrivilegedHelperInstallSnapshot(helperToolExists: false, launchDaemonExists: false)
        let partial = PrivilegedHelperInstallSnapshot(helperToolExists: true, launchDaemonExists: false)
        let installed = PrivilegedHelperInstallSnapshot(helperToolExists: true, launchDaemonExists: true)

        XCTAssertTrue(missing.requiresUserAction)
        XCTAssertEqual(missing.guidanceTitle, "권한 도우미 설치 필요")
        XCTAssertTrue(missing.guidanceDetail.contains("Install Privileged Helper.command"))

        XCTAssertTrue(partial.requiresUserAction)
        XCTAssertEqual(partial.guidanceTitle, "권한 도우미 복구 필요")
        XCTAssertTrue(partial.guidanceDetail.contains("제거 후 다시 설치"))

        XCTAssertFalse(installed.requiresUserAction)
        XCTAssertEqual(installed.guidanceTitle, "권한 도우미 준비됨")
        XCTAssertTrue(installed.guidanceDetail.contains("권한 도우미 XPC"))
    }
}

private struct RecordingFileChecker: PrivilegedHelperFileChecking, Sendable {
    let existingPaths: Set<String>

    func fileExists(atPath path: String) -> Bool {
        existingPaths.contains(path)
    }
}
