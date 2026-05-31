import XCTest
@testable import MacDog

final class PrivilegedHelperInstallerTests: XCTestCase {
    func testHostDesignatedRequirementParserAcceptsCodesignCommentPrefix() {
        let output = """
        Executable=/Applications/MacDog.app/Contents/MacOS/MacDog
        # designated => cdhash H"ab14bda1a81116cb5e09cfae6ba709726dcee29b"
        """

        XCTAssertEqual(
            PrivilegedHelperInstaller.hostDesignatedRequirement(from: output),
            #"cdhash H"ab14bda1a81116cb5e09cfae6ba709726dcee29b""#
        )
    }

    func testHostDesignatedRequirementParserKeepsLegacyUnprefixedOutput() {
        let output = #"designated => identifier "com.dhseo.macdog.MacDog""#

        XCTAssertEqual(
            PrivilegedHelperInstaller.hostDesignatedRequirement(from: output),
            #"identifier "com.dhseo.macdog.MacDog""#
        )
    }

    func testHostDesignatedRequirementParserRejectsEmptyRequirement() {
        XCTAssertNil(PrivilegedHelperInstaller.hostDesignatedRequirement(from: "# designated =>"))
    }
}
