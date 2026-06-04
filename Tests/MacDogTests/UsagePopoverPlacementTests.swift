import AppKit
import XCTest
@testable import MacDog

final class UsagePopoverPlacementTests: XCTestCase {
    func testMenuBarAnchorNarrowsStatusItemBounds() {
        let anchor = UsagePopoverPlacementResolver.anchorRect(
            sourceBounds: NSRect(x: 0, y: 0, width: 38, height: 22),
            placement: .menuBar
        )

        XCTAssertEqual(anchor.origin.x, 7)
        XCTAssertEqual(anchor.origin.y, 0)
        XCTAssertEqual(anchor.size.width, 24)
        XCTAssertEqual(anchor.size.height, 22)
    }

    func testDesktopPreferredEdgeFollowsSourceSide() {
        let screenFrame = NSRect(x: 0, y: 0, width: 1_000, height: 800)
        let leftSourceFrame = NSRect(x: 120, y: 200, width: 96, height: 102)
        let rightSourceFrame = NSRect(x: 820, y: 200, width: 96, height: 102)

        XCTAssertEqual(
            UsagePopoverPlacementResolver.preferredEdge(
                sourceFrame: leftSourceFrame,
                screenFrame: screenFrame,
                placement: .desktopPet
            ),
            .maxX
        )
        XCTAssertEqual(
            UsagePopoverPlacementResolver.preferredEdge(
                sourceFrame: rightSourceFrame,
                screenFrame: screenFrame,
                placement: .desktopPet
            ),
            .minX
        )
        XCTAssertEqual(
            UsagePopoverPlacementResolver.preferredEdge(
                sourceFrame: rightSourceFrame,
                screenFrame: screenFrame,
                placement: .menuBar
            ),
            .maxY
        )
    }

    func testMenuBarPopoverFrameCentersUnderSourceAndClampsToScreen() {
        let frame = UsagePopoverPlacementResolver.resolvedWindowFrame(
            currentPopoverFrame: NSRect(x: 0, y: 0, width: 370, height: 408),
            sourceFrame: NSRect(x: 970, y: 760, width: 38, height: 22),
            screenFrame: NSRect(x: 0, y: 0, width: 1_000, height: 800),
            placement: .menuBar
        )

        XCTAssertLessThanOrEqual(frame.maxX, 992)
        XCTAssertGreaterThanOrEqual(frame.minX, 8)
        XCTAssertLessThanOrEqual(frame.maxY, 792)
        XCTAssertGreaterThanOrEqual(frame.minY, 8)
    }

    func testDesktopPopoverFrameUsesNearestSideAndClampsToScreen() {
        let frame = UsagePopoverPlacementResolver.resolvedWindowFrame(
            currentPopoverFrame: NSRect(x: 0, y: 0, width: 370, height: 408),
            sourceFrame: NSRect(x: 820, y: 12, width: 96, height: 102),
            screenFrame: NSRect(x: 0, y: 0, width: 1_000, height: 800),
            placement: .desktopPet
        )

        XCTAssertEqual(frame.origin.x, 442)
        XCTAssertGreaterThanOrEqual(frame.minY, 8)
        XCTAssertLessThanOrEqual(frame.maxY, 792)
    }
}
