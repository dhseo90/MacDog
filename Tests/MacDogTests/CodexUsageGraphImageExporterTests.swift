import AppKit
import SwiftUI
import XCTest
@testable import MacDog

@MainActor
final class CodexUsageGraphImageExporterTests: XCTestCase {
    func testRendersPNGDataWithoutSensitiveMetadataStrings() throws {
        let data = try XCTUnwrap(CodexUsageGraphImageExporter.pngData(
            for: Text("Usage")
                .frame(width: 120, height: 48),
            size: CGSize(width: 120, height: 48),
            scale: 1
        ))

        XCTAssertEqual(Array(data.prefix(8)), [137, 80, 78, 71, 13, 10, 26, 10])

        let text = String(decoding: data, as: UTF8.self)
        for forbidden in [
            "access_token",
            "refresh_token",
            "authorization",
            "cookie",
            "session",
            "rawResponse",
            "/Users/"
        ] {
            XCTAssertFalse(
                text.localizedCaseInsensitiveContains(forbidden),
                "PNG export must not include \(forbidden)"
            )
        }
    }

    func testCopyWritesOnlyPNGDataToPasteboard() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        let data = Data([137, 80, 78, 71, 13, 10, 26, 10, 0, 0])

        XCTAssertTrue(CodexUsageGraphImageExporter.copyPNGData(data, to: pasteboard))

        XCTAssertTrue(pasteboard.types?.contains(.png) == true)
        XCTAssertFalse(pasteboard.types?.contains(.string) == true)
        XCTAssertFalse(pasteboard.types?.contains(.fileURL) == true)
        XCTAssertEqual(pasteboard.data(forType: .png), data)
        XCTAssertNil(pasteboard.string(forType: .string))
        XCTAssertNil(pasteboard.string(forType: .fileURL))
    }
}
