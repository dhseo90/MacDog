import XCTest
@testable import MacDog

final class ChargeLimitSupportSnapshotTests: XCTestCase {
    func testAppleSiliconOnSupportedOSShowsNativeChargeLimitAvailable() {
        let snapshot = ChargeLimitSupportSnapshot(
            operatingSystemVersion: OperatingSystemVersion(majorVersion: 26, minorVersion: 4, patchVersion: 0),
            isAppleSilicon: true
        )

        XCTAssertTrue(snapshot.isNativeChargeLimitAvailable)
        XCTAssertEqual(snapshot.summary, "지원 가능 · 80~100%")
    }

    func testIntelMacShowsAppleSiliconRequirement() {
        let snapshot = ChargeLimitSupportSnapshot(
            operatingSystemVersion: OperatingSystemVersion(majorVersion: 26, minorVersion: 4, patchVersion: 0),
            isAppleSilicon: false
        )

        XCTAssertFalse(snapshot.isNativeChargeLimitAvailable)
        XCTAssertEqual(snapshot.summary, "미지원 · Apple silicon 필요")
    }

    func testAppleSiliconOnUnsupportedOSShowsVersionRequirement() {
        let snapshot = ChargeLimitSupportSnapshot(
            operatingSystemVersion: OperatingSystemVersion(majorVersion: 26, minorVersion: 3, patchVersion: 9),
            isAppleSilicon: true
        )

        XCTAssertFalse(snapshot.isNativeChargeLimitAvailable)
        XCTAssertEqual(snapshot.summary, "미지원 · macOS 26.4+ 필요")
    }

    func testBatterySettingsDestinationStartsWithSystemSettingsURL() throws {
        let firstURL = try XCTUnwrap(SystemSettingsDestination.batterySettingsURLCandidates.first)

        XCTAssertEqual(firstURL.scheme, "x-apple.systempreferences")
        XCTAssertEqual(firstURL.absoluteString, "x-apple.systempreferences:com.apple.Battery-Settings.extension")
    }

    func testFloatingPetMenuPlacementUsesRightSideInLeftHalfOfScreen() {
        let placement = FloatingPetMenuPlacement.resolve(
            petFrame: NSRect(x: 120, y: 200, width: 96, height: 102),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800),
            clickPoint: NSPoint(x: 160, y: 240),
            menuSize: NSSize(width: 220, height: 260)
        )

        XCTAssertEqual(placement.side, .right)
        XCTAssertEqual(placement.origin.x, 224)
    }

    func testFloatingPetMenuPlacementUsesLeftSideInRightHalfOfScreen() {
        let placement = FloatingPetMenuPlacement.resolve(
            petFrame: NSRect(x: 820, y: 200, width: 96, height: 102),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800),
            clickPoint: NSPoint(x: 850, y: 240),
            menuSize: NSSize(width: 220, height: 260)
        )

        XCTAssertEqual(placement.side, .left)
        XCTAssertEqual(placement.origin.x, 592)
    }

    func testFloatingPetMenuPlacementClampsInsideVisibleFrame() {
        let placement = FloatingPetMenuPlacement.resolve(
            petFrame: NSRect(x: 940, y: 10, width: 96, height: 102),
            visibleFrame: NSRect(x: 0, y: 0, width: 1000, height: 800),
            clickPoint: NSPoint(x: 960, y: 20),
            menuSize: NSSize(width: 900, height: 760)
        )

        XCTAssertEqual(placement.side, .left)
        XCTAssertGreaterThanOrEqual(placement.origin.x, 8)
        XCTAssertLessThanOrEqual(placement.origin.x + 900, 992)
        XCTAssertGreaterThanOrEqual(placement.origin.y, 768)
        XCTAssertLessThanOrEqual(placement.origin.y, 792)
    }
}
