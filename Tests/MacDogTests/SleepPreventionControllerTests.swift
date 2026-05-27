import IOKit.pwr_mgt
import XCTest
@testable import MacDog

final class SleepPreventionControllerTests: XCTestCase {
    func testEnablingAcquiresDisplayAndSystemSleepAssertions() {
        let assertionManager = RecordingPowerAssertionManager()
        let controller = SleepPreventionController(assertionManager: assertionManager)

        controller.setEnabled(true, endsAt: nil)

        XCTAssertTrue(controller.status.isActive)
        XCTAssertNil(controller.status.errorMessage)
        XCTAssertEqual(assertionManager.createdAssertionTypes, [
            "PreventUserIdleDisplaySleep",
            "PreventUserIdleSystemSleep"
        ])
    }

    func testDisablingReleasesAllAssertions() {
        let assertionManager = RecordingPowerAssertionManager()
        let controller = SleepPreventionController(assertionManager: assertionManager)

        controller.setEnabled(true, endsAt: nil)
        controller.setEnabled(false, endsAt: nil)

        XCTAssertFalse(controller.status.isActive)
        XCTAssertEqual(assertionManager.releasedAssertionIDs.sorted(), [1, 2])
    }

    func testPartialAcquireFailureReleasesAlreadyCreatedAssertions() {
        let assertionManager = RecordingPowerAssertionManager(
            failingAssertionType: "PreventUserIdleSystemSleep"
        )
        let controller = SleepPreventionController(assertionManager: assertionManager)

        controller.setEnabled(true, endsAt: nil)

        XCTAssertFalse(controller.status.isActive)
        XCTAssertEqual(controller.status.errorMessage, "system IOKit \(kIOReturnError)")
        XCTAssertEqual(assertionManager.createdAssertionTypes, [
            "PreventUserIdleDisplaySleep",
            "PreventUserIdleSystemSleep"
        ])
        XCTAssertEqual(assertionManager.releasedAssertionIDs, [1])
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
