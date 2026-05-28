import XCTest
@testable import MacDogPrivilegedHelperSupport

final class PrivilegedHelperHostAuthorizationTests: XCTestCase {
    func testRuntimeRequirementUsesTeamIdentifierWhenProvided() {
        let requirement = PrivilegedHelperHostRequirement.runtime(environment: [
            "MACDOG_HELPER_HOST_TEAM_ID": "TEAM123456"
        ])

        XCTAssertEqual(requirement.bundleIdentifier, "com.dhseo.macdog.MacDog")
        XCTAssertEqual(
            requirement.requirementString,
            #"identifier "com.dhseo.macdog.MacDog" and anchor apple generic and certificate leaf[subject.OU] = "TEAM123456""#
        )
    }

    func testRuntimeRequirementRejectsAdHocByDefault() {
        let requirement = PrivilegedHelperHostRequirement.runtime(environment: [:])

        XCTAssertFalse(requirement.acceptsAdHocDevelopmentSignature)
        XCTAssertEqual(
            requirement.requirementString,
            #"identifier "com.dhseo.macdog.MacDog" and anchor apple generic"#
        )
    }

    func testAdHocDevelopmentRequirementIsExplicit() {
        let requirement = PrivilegedHelperHostRequirement.runtime(environment: [
            "MACDOG_HELPER_ALLOW_ADHOC_HOST": "1"
        ])

        XCTAssertTrue(requirement.acceptsAdHocDevelopmentSignature)
        XCTAssertEqual(requirement.requirementString, #"identifier "com.dhseo.macdog.MacDog""#)
    }

    func testRequirementEscapesValues() {
        let requirement = PrivilegedHelperHostRequirement(
            bundleIdentifier: #"com.example."quoted""#,
            teamIdentifier: #"TEAM\"ID"#
        )

        XCTAssertEqual(
            requirement.requirementString,
            #"identifier "com.example.\"quoted\"" and anchor apple generic and certificate leaf[subject.OU] = "TEAM\\\"ID""#
        )
    }

    func testSecCodeAuthorizerRejectsInvalidPid() {
        let authorizer = SecCodePrivilegedHelperConnectionAuthorizer(
            requirement: PrivilegedHelperHostRequirement()
        )

        XCTAssertFalse(authorizer.shouldAccept(processIdentifier: 0))
        XCTAssertFalse(authorizer.shouldAccept(processIdentifier: -1))
    }
}
