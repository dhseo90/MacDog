import XCTest
@testable import MacDog

final class FloatingPetMotionBoundsTests: XCTestCase {
    func testClampKeepsPetInsideVisibleFrame() {
        let origin = FloatingPetMotionBounds.clamped(
            origin: NSPoint(x: -30, y: 760),
            size: NSSize(width: 96, height: 102),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800)
        )

        XCTAssertEqual(origin.x, 0)
        XCTAssertEqual(origin.y, 698)
    }

    func testHeadingTowardSafeAreaReturnsNilWhenAlreadySafe() {
        let heading = FloatingPetMotionBounds.headingTowardSafeAreaIfNeeded(
            frame: NSRect(x: 300, y: 260, width: 96, height: 102),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800)
        )

        XCTAssertNil(heading)
    }

    func testHeadingTowardSafeAreaPointsRightFromLeftEdge() throws {
        let heading = try XCTUnwrap(FloatingPetMotionBounds.headingTowardSafeAreaIfNeeded(
            frame: NSRect(x: 0, y: 260, width: 96, height: 102),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800)
        ))

        XCTAssertEqual(heading, 0, accuracy: 0.001)
    }

    func testHeadingTowardSafeAreaPointsDownFromTopEdge() throws {
        let heading = try XCTUnwrap(FloatingPetMotionBounds.headingTowardSafeAreaIfNeeded(
            frame: NSRect(x: 300, y: 720, width: 96, height: 102),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800)
        ))

        XCTAssertEqual(heading, -CGFloat.pi / 2, accuracy: 0.001)
    }
}
