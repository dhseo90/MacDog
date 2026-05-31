import IOKit.pwr_mgt
import XCTest
@testable import MacDog

final class SleepPreventionControllerTests: XCTestCase {
    func testEnablingAcquiresDisplayAndSystemSleepAssertions() {
        let assertionManager = RecordingPowerAssertionManager()
        let closedLidSleepDisabler = RecordingClosedLidSleepDisabler()
        let screenLockDisabler = RecordingScreenLockDisabler()
        let controller = SleepPreventionController(
            assertionManager: assertionManager,
            closedLidSleepDisabler: closedLidSleepDisabler,
            screenLockDisabler: screenLockDisabler
        )

        controller.setEnabled(true, endsAt: nil)

        XCTAssertTrue(controller.status.isActive)
        XCTAssertTrue(controller.status.isClosedLidSleepDisabled)
        XCTAssertTrue(controller.status.isScreenLockDisabled)
        XCTAssertNil(controller.status.errorMessage)
        XCTAssertNil(controller.status.screenLockWarningMessage)
        XCTAssertEqual(assertionManager.createdAssertionTypes, [
            "PreventUserIdleDisplaySleep",
            "PreventUserIdleSystemSleep",
            "NetworkClientActive"
        ])
        XCTAssertEqual(closedLidSleepDisabler.requests, [true])
        XCTAssertEqual(screenLockDisabler.requests, [true])
    }

    func testDisplaySleepPreventionCanBeDisabledPerSessionPolicy() {
        let assertionManager = RecordingPowerAssertionManager()
        let controller = SleepPreventionController(
            assertionManager: assertionManager,
            closedLidSleepDisabler: RecordingClosedLidSleepDisabler(),
            screenLockDisabler: RecordingScreenLockDisabler()
        )

        controller.setEnabled(
            true,
            endsAt: nil,
            policy: SleepPreventionPolicy(
                preventDisplaySleep: false,
                preventClosedLidSleep: true,
                disableScreenLock: true
            )
        )

        XCTAssertTrue(controller.status.isActive)
        XCTAssertEqual(assertionManager.createdAssertionTypes, [
            "PreventUserIdleSystemSleep",
            "NetworkClientActive"
        ])
    }

    func testClosedLidProtectionCanBeDisabledPerSessionPolicy() {
        let assertionManager = RecordingPowerAssertionManager()
        let closedLidSleepDisabler = RecordingClosedLidSleepDisabler()
        let controller = SleepPreventionController(
            assertionManager: assertionManager,
            closedLidSleepDisabler: closedLidSleepDisabler,
            screenLockDisabler: RecordingScreenLockDisabler()
        )

        controller.setEnabled(
            true,
            endsAt: nil,
            policy: SleepPreventionPolicy(
                preventDisplaySleep: true,
                preventClosedLidSleep: false,
                disableScreenLock: true
            )
        )

        XCTAssertTrue(controller.status.isActive)
        XCTAssertFalse(controller.status.isClosedLidSleepDisabled)
        XCTAssertEqual(assertionManager.createdAssertionTypes, [
            "PreventUserIdleDisplaySleep",
            "PreventUserIdleSystemSleep"
        ])
        XCTAssertTrue(closedLidSleepDisabler.requests.isEmpty)
    }

    func testScreenLockCanBeLeftUntouchedPerSessionPolicy() {
        let screenLockDisabler = RecordingScreenLockDisabler()
        let controller = SleepPreventionController(
            assertionManager: RecordingPowerAssertionManager(),
            closedLidSleepDisabler: RecordingClosedLidSleepDisabler(),
            screenLockDisabler: screenLockDisabler
        )

        controller.setEnabled(
            true,
            endsAt: nil,
            policy: SleepPreventionPolicy(
                preventDisplaySleep: true,
                preventClosedLidSleep: true,
                disableScreenLock: false
            )
        )

        XCTAssertTrue(controller.status.isActive)
        XCTAssertFalse(controller.status.isScreenLockDisabled)
        XCTAssertTrue(screenLockDisabler.requests.isEmpty)
    }

    func testChangingPolicyWhileEnabledRestoresDisabledScopes() {
        let assertionManager = RecordingPowerAssertionManager()
        let closedLidSleepDisabler = RecordingClosedLidSleepDisabler()
        let screenLockDisabler = RecordingScreenLockDisabler()
        let controller = SleepPreventionController(
            assertionManager: assertionManager,
            closedLidSleepDisabler: closedLidSleepDisabler,
            screenLockDisabler: screenLockDisabler
        )

        controller.setEnabled(true, endsAt: nil)
        controller.setEnabled(
            true,
            endsAt: nil,
            policy: SleepPreventionPolicy(
                preventDisplaySleep: false,
                preventClosedLidSleep: false,
                disableScreenLock: false
            )
        )

        XCTAssertTrue(controller.status.isActive)
        XCTAssertFalse(controller.status.isClosedLidSleepDisabled)
        XCTAssertFalse(controller.status.isScreenLockDisabled)
        XCTAssertEqual(assertionManager.releasedAssertionIDs.sorted(), [1, 3])
        XCTAssertEqual(closedLidSleepDisabler.requests, [true, false])
        XCTAssertEqual(screenLockDisabler.requests, [true, false])
    }

    func testDisablingReleasesAllAssertions() {
        let assertionManager = RecordingPowerAssertionManager()
        let closedLidSleepDisabler = RecordingClosedLidSleepDisabler()
        let screenLockDisabler = RecordingScreenLockDisabler()
        let controller = SleepPreventionController(
            assertionManager: assertionManager,
            closedLidSleepDisabler: closedLidSleepDisabler,
            screenLockDisabler: screenLockDisabler
        )

        controller.setEnabled(true, endsAt: nil)
        controller.setEnabled(false, endsAt: nil)

        XCTAssertFalse(controller.status.isActive)
        XCTAssertFalse(controller.status.isClosedLidSleepDisabled)
        XCTAssertFalse(controller.status.isScreenLockDisabled)
        XCTAssertEqual(assertionManager.releasedAssertionIDs.sorted(), [1, 2, 3])
        XCTAssertEqual(closedLidSleepDisabler.requests, [true, false])
        XCTAssertEqual(screenLockDisabler.requests, [true, false])
    }

    func testDeinitReleasesAssertionsWithoutRestoringGlobalSettings() {
        let assertionManager = RecordingPowerAssertionManager()
        let closedLidSleepDisabler = RecordingClosedLidSleepDisabler()
        let screenLockDisabler = RecordingScreenLockDisabler()
        var controller: SleepPreventionController? = SleepPreventionController(
            assertionManager: assertionManager,
            closedLidSleepDisabler: closedLidSleepDisabler,
            screenLockDisabler: screenLockDisabler
        )

        controller?.setEnabled(true, endsAt: nil)
        controller = nil

        XCTAssertEqual(assertionManager.releasedAssertionIDs.sorted(), [1, 2, 3])
        XCTAssertEqual(closedLidSleepDisabler.requests, [true])
        XCTAssertEqual(screenLockDisabler.requests, [true])
    }

    func testPartialAcquireFailureReleasesAlreadyCreatedAssertions() {
        let assertionManager = RecordingPowerAssertionManager(
            failingAssertionType: "PreventUserIdleSystemSleep"
        )
        let closedLidSleepDisabler = RecordingClosedLidSleepDisabler()
        let controller = SleepPreventionController(
            assertionManager: assertionManager,
            closedLidSleepDisabler: closedLidSleepDisabler,
            screenLockDisabler: RecordingScreenLockDisabler()
        )

        controller.setEnabled(true, endsAt: nil)

        XCTAssertFalse(controller.status.isActive)
        XCTAssertFalse(controller.status.isClosedLidSleepDisabled)
        XCTAssertEqual(controller.status.errorMessage, "system IOKit \(kIOReturnError)")
        XCTAssertEqual(assertionManager.createdAssertionTypes, [
            "PreventUserIdleDisplaySleep",
            "PreventUserIdleSystemSleep"
        ])
        XCTAssertEqual(assertionManager.releasedAssertionIDs, [1])
        XCTAssertTrue(closedLidSleepDisabler.requests.isEmpty)
    }

    func testClosedLidDisableFailureKeepsPowerAssertionsAndReportsWarning() {
        let assertionManager = RecordingPowerAssertionManager()
        let closedLidSleepDisabler = RecordingClosedLidSleepDisabler(enableError: TestClosedLidError.denied)
        let controller = SleepPreventionController(
            assertionManager: assertionManager,
            closedLidSleepDisabler: closedLidSleepDisabler,
            screenLockDisabler: RecordingScreenLockDisabler()
        )

        controller.setEnabled(true, endsAt: nil)
        controller.setEnabled(true, endsAt: nil)

        XCTAssertTrue(controller.status.isActive)
        XCTAssertFalse(controller.status.isClosedLidSleepDisabled)
        XCTAssertNil(controller.status.errorMessage)
        XCTAssertEqual(controller.status.closedLidWarningMessage, "관리자 권한이 거부되었습니다.")
        XCTAssertEqual(closedLidSleepDisabler.requests, [true])
    }

    func testClosedLidDisableRetriesAfterHelperInstallMakesRetrySafe() {
        let assertionManager = RecordingPowerAssertionManager()
        let closedLidSleepDisabler = RecordingClosedLidSleepDisabler(
            enableError: TestClosedLidError.denied,
            enableFailuresBeforeSuccess: 1,
            canRetryWithoutUserApproval: true
        )
        let controller = SleepPreventionController(
            assertionManager: assertionManager,
            closedLidSleepDisabler: closedLidSleepDisabler,
            screenLockDisabler: RecordingScreenLockDisabler()
        )

        controller.setEnabled(true, endsAt: nil)
        controller.setEnabled(true, endsAt: nil)

        XCTAssertTrue(controller.status.isActive)
        XCTAssertTrue(controller.status.isClosedLidSleepDisabled)
        XCTAssertNil(controller.status.errorMessage)
        XCTAssertNil(controller.status.closedLidWarningMessage)
        XCTAssertEqual(closedLidSleepDisabler.requests, [true, true])
    }

    func testScreenLockDisableFailureKeepsPowerAssertionsAndReportsWarning() {
        let assertionManager = RecordingPowerAssertionManager()
        let controller = SleepPreventionController(
            assertionManager: assertionManager,
            closedLidSleepDisabler: RecordingClosedLidSleepDisabler(),
            screenLockDisabler: RecordingScreenLockDisabler(enableError: TestClosedLidError.denied)
        )

        controller.setEnabled(true, endsAt: nil)

        XCTAssertTrue(controller.status.isActive)
        XCTAssertTrue(controller.status.isClosedLidSleepDisabled)
        XCTAssertFalse(controller.status.isScreenLockDisabled)
        XCTAssertNil(controller.status.errorMessage)
        XCTAssertNil(controller.status.closedLidWarningMessage)
        XCTAssertEqual(controller.status.screenLockWarningMessage, "관리자 권한이 거부되었습니다.")
    }

    func testScreenLockDisableRetriesOnNextSyncAfterFailure() {
        let assertionManager = RecordingPowerAssertionManager()
        let screenLockDisabler = RecordingScreenLockDisabler(
            enableError: TestClosedLidError.denied,
            enableFailuresBeforeSuccess: 1
        )
        let controller = SleepPreventionController(
            assertionManager: assertionManager,
            closedLidSleepDisabler: RecordingClosedLidSleepDisabler(),
            screenLockDisabler: screenLockDisabler
        )

        controller.setEnabled(true, endsAt: nil)
        controller.setEnabled(true, endsAt: nil)

        XCTAssertTrue(controller.status.isScreenLockDisabled)
        XCTAssertNil(controller.status.screenLockWarningMessage)
        XCTAssertEqual(screenLockDisabler.requests, [true, true])
    }
}

private final class RecordingPowerAssertionManager: PowerAssertionManaging {
    private let failingAssertionType: String?
    private var nextAssertionID = IOPMAssertionID(1)

    private(set) var createdAssertionTypes: [String] = []
    private(set) var releasedAssertionIDs: [IOPMAssertionID] = []

    init(failingAssertionType: String? = nil) {
        self.failingAssertionType = failingAssertionType
    }

    func createAssertion(type: CFString, reason: CFString) -> (IOReturn, IOPMAssertionID) {
        let assertionType = type as String
        createdAssertionTypes.append(assertionType)

        if assertionType == failingAssertionType {
            return (kIOReturnError, 0)
        }

        let assertionID = nextAssertionID
        nextAssertionID += 1
        return (kIOReturnSuccess, assertionID)
    }

    func releaseAssertion(_ assertionID: IOPMAssertionID) {
        releasedAssertionIDs.append(assertionID)
    }
}

private final class RecordingClosedLidSleepDisabler: ClosedLidSleepDisabling {
    private let enableError: Error?
    private var enableFailuresBeforeSuccess: Int
    let canRetryWithoutUserApproval: Bool
    private(set) var requests: [Bool] = []

    init(
        enableError: Error? = nil,
        enableFailuresBeforeSuccess: Int? = nil,
        canRetryWithoutUserApproval: Bool = false
    ) {
        self.enableError = enableError
        self.enableFailuresBeforeSuccess = enableFailuresBeforeSuccess ?? (enableError == nil ? 0 : Int.max)
        self.canRetryWithoutUserApproval = canRetryWithoutUserApproval
    }

    func setClosedLidSleepDisabled(_ isDisabled: Bool) throws -> Bool {
        requests.append(isDisabled)
        if isDisabled, let enableError, enableFailuresBeforeSuccess > 0 {
            enableFailuresBeforeSuccess -= 1
            throw enableError
        }
        return isDisabled
    }
}

private final class RecordingScreenLockDisabler: ScreenLockDisabling {
    private let enableError: Error?
    private var enableFailuresBeforeSuccess: Int
    private(set) var requests: [Bool] = []

    init(enableError: Error? = nil, enableFailuresBeforeSuccess: Int? = nil) {
        self.enableError = enableError
        self.enableFailuresBeforeSuccess = enableFailuresBeforeSuccess ?? (enableError == nil ? 0 : Int.max)
    }

    func setScreenLockDisabled(_ isDisabled: Bool) throws -> Bool {
        requests.append(isDisabled)
        if isDisabled, let enableError, enableFailuresBeforeSuccess > 0 {
            enableFailuresBeforeSuccess -= 1
            throw enableError
        }
        return isDisabled
    }
}

private enum TestClosedLidError: LocalizedError {
    case denied

    var errorDescription: String? {
        "관리자 권한이 거부되었습니다."
    }
}
