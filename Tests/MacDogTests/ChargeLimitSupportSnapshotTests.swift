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
}
