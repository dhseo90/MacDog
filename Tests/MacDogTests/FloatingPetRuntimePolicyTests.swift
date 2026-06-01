import XCTest
@testable import MacDog

final class FloatingPetRuntimePolicyTests: XCTestCase {
    func testCalmAndActiveMotionUseLowerFrequencyThanFastStates() {
        XCTAssertEqual(FloatingPetRuntimePolicy.motionTickInterval(for: .calm), 1.0 / 20.0)
        XCTAssertEqual(FloatingPetRuntimePolicy.motionTickInterval(for: .active), 1.0 / 24.0)
        XCTAssertEqual(FloatingPetRuntimePolicy.motionTickInterval(for: .fast), 1.0 / 30.0)
        XCTAssertEqual(FloatingPetRuntimePolicy.motionTickInterval(for: .sprint), 1.0 / 30.0)
        XCTAssertEqual(FloatingPetRuntimePolicy.motionTickInterval(for: .limit), 1.0 / 30.0)
    }

    func testStationaryPetUsesFrameIntervalInsteadOfMotionTick() {
        XCTAssertEqual(
            FloatingPetRuntimePolicy.updateTimerInterval(
                canMove: false,
                phase: .calm,
                frameInterval: 1.5
            ),
            1.5
        )
        XCTAssertEqual(
            FloatingPetRuntimePolicy.updateTimerInterval(
                canMove: true,
                phase: .calm,
                frameInterval: 1.5
            ),
            1.0 / 20.0
        )
    }

    func testTimerToleranceIsBounded() {
        XCTAssertEqual(FloatingPetRuntimePolicy.timerTolerance(for: 0.04), 0.01, accuracy: 0.0001)
        XCTAssertEqual(FloatingPetRuntimePolicy.timerTolerance(for: 1.5), 0.08, accuracy: 0.0001)
    }
}
