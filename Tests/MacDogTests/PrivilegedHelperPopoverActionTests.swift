import XCTest
import MacDogPrivilegedHelperSupport
@testable import MacDog

final class PrivilegedHelperPopoverActionTests: XCTestCase {
    func testMissingHelperOffersInstallOnly() {
        let actions = PrivilegedHelperPopoverAction.actions(
            for: PrivilegedHelperInstallSnapshot(helperToolExists: false, launchDaemonExists: false)
        )

        XCTAssertEqual(
            actions,
            [
                PrivilegedHelperPopoverAction(
                    title: "도우미 설치",
                    systemImage: "plus.circle",
                    action: .installPrivilegedHelper
                )
            ]
        )
    }

    func testPartialHelperOffersRemoveThenReinstall() {
        let actions = PrivilegedHelperPopoverAction.actions(
            for: PrivilegedHelperInstallSnapshot(helperToolExists: true, launchDaemonExists: false)
        )

        XCTAssertEqual(
            actions,
            [
                PrivilegedHelperPopoverAction(
                    title: "제거",
                    systemImage: "trash",
                    action: .uninstallPrivilegedHelper
                ),
                PrivilegedHelperPopoverAction(
                    title: "다시 설치",
                    systemImage: "arrow.clockwise",
                    action: .installPrivilegedHelper
                )
            ]
        )
    }

    func testInstalledHelperOffersRemoveOnly() {
        let actions = PrivilegedHelperPopoverAction.actions(
            for: PrivilegedHelperInstallSnapshot(helperToolExists: true, launchDaemonExists: true)
        )

        XCTAssertEqual(
            actions,
            [
                PrivilegedHelperPopoverAction(
                    title: "도우미 제거",
                    systemImage: "trash",
                    action: .uninstallPrivilegedHelper
                )
            ]
        )
    }
}
