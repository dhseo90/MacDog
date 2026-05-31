import XCTest
@testable import MacDogPrivilegedHelperSupport

final class PrivilegedHelperContractTests: XCTestCase {
    func testRequestEncodingKeepsStableCommandNames() throws {
        let request = PrivilegedHelperRequest(command: .setSleepDisabled(true))
        let data = try JSONEncoder().encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let command = try XCTUnwrap(object["command"] as? [String: Any])

        XCTAssertEqual(object["protocolVersion"] as? Int, 1)
        XCTAssertEqual(command["name"] as? String, "setSleepDisabled")
        XCTAssertEqual(command["sleepDisabled"] as? Bool, true)
        XCTAssertEqual(try JSONDecoder().decode(PrivilegedHelperRequest.self, from: data), request)
    }

    func testScreenLockRequestEncodingKeepsStableCommandNames() throws {
        let request = PrivilegedHelperRequest(command: .setScreenLockDelay(.seconds(30)))
        let data = try JSONEncoder().encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let command = try XCTUnwrap(object["command"] as? [String: Any])
        let delay = try XCTUnwrap(command["screenLockDelay"] as? [String: Any])

        XCTAssertEqual(command["name"] as? String, "setScreenLockDelay")
        XCTAssertEqual(delay["name"] as? String, "seconds")
        XCTAssertEqual(delay["seconds"] as? Int, 30)
        XCTAssertEqual(try JSONDecoder().decode(PrivilegedHelperRequest.self, from: data), request)
    }

    func testPlannerAllowsOnlyPmsetSleepDisabledCommands() {
        XCTAssertEqual(
            PrivilegedHelperCommandPlanner.pmsetInvocation(for: .readSleepDisabled),
            PMSetInvocation(executablePath: "/usr/bin/pmset", arguments: ["-g", "live"])
        )
        XCTAssertEqual(
            PrivilegedHelperCommandPlanner.pmsetInvocation(for: .setSleepDisabled(true)),
            PMSetInvocation(executablePath: "/usr/bin/pmset", arguments: ["-a", "disablesleep", "1"])
        )
        XCTAssertEqual(
            PrivilegedHelperCommandPlanner.pmsetInvocation(for: .setSleepDisabled(false)),
            PMSetInvocation(executablePath: "/usr/bin/pmset", arguments: ["-a", "disablesleep", "0"])
        )
    }

    func testPlannerAllowsOnlySysadminctlScreenLockCommands() {
        XCTAssertEqual(
            PrivilegedHelperCommandPlanner.sysadminctlInvocation(for: .readScreenLockDelay),
            PMSetInvocation(executablePath: "/usr/sbin/sysadminctl", arguments: ["-screenLock", "status"])
        )
        XCTAssertEqual(
            PrivilegedHelperCommandPlanner.sysadminctlInvocation(for: .setScreenLockDelay(.off)),
            PMSetInvocation(executablePath: "/usr/sbin/sysadminctl", arguments: ["-screenLock", "off"])
        )
        XCTAssertEqual(
            PrivilegedHelperCommandPlanner.sysadminctlInvocation(for: .setScreenLockDelay(.immediate)),
            PMSetInvocation(executablePath: "/usr/sbin/sysadminctl", arguments: ["-screenLock", "immediate"])
        )
        XCTAssertEqual(
            PrivilegedHelperCommandPlanner.sysadminctlInvocation(for: .setScreenLockDelay(.seconds(60))),
            PMSetInvocation(executablePath: "/usr/sbin/sysadminctl", arguments: ["-screenLock", "60"])
        )
        XCTAssertNil(PrivilegedHelperCommandPlanner.sysadminctlInvocation(for: .setScreenLockDelay(.unknown("custom"))))
        XCTAssertNil(PrivilegedHelperCommandPlanner.sysadminctlInvocation(for: .setSleepDisabled(true)))
    }

    func testSleepDisabledParserReadsLivePmsetOutput() throws {
        XCTAssertTrue(try SleepDisabledLiveParser.parse("System-wide power settings:\n SleepDisabled\t\t1\n"))
        XCTAssertFalse(try SleepDisabledLiveParser.parse("System-wide power settings:\n SleepDisabled\t\t0\n"))
    }

    func testSleepDisabledParserRejectsMissingOrUnknownValues() {
        XCTAssertThrowsError(try SleepDisabledLiveParser.parse("System-wide power settings:\n sleep 1\n")) { error in
            XCTAssertEqual(error as? PrivilegedHelperContractError, .missingSleepDisabledValue)
        }

        XCTAssertThrowsError(try SleepDisabledLiveParser.parse("System-wide power settings:\n SleepDisabled 2\n")) { error in
            XCTAssertEqual(error as? PrivilegedHelperContractError, .invalidSleepDisabledValue("2"))
        }
    }

    func testScreenLockDelayParserReadsSysadminctlOutput() {
        XCTAssertEqual(ScreenLockDelayParser.parse("screenLock delay is off"), .off)
        XCTAssertEqual(ScreenLockDelayParser.parse("screenLock delay is immediate"), .immediate)
        XCTAssertEqual(ScreenLockDelayParser.parse("screenLock delay is 300"), .seconds(300))
        XCTAssertEqual(ScreenLockDelayParser.parse("custom policy"), .unknown("custom policy"))
    }

    func testInstallPlanDocumentsNaturalInstallLocations() {
        let plan = PrivilegedHelperInstallPlan.current
        let dryRun = plan.dryRunLines(appBundlePath: "/Applications/MacDog.app").joined(separator: "\n")

        XCTAssertEqual(plan.label, "com.dhseo.macdog.helper")
        XCTAssertTrue(dryRun.contains("/Applications/MacDog.app/Contents/Library/LaunchServices/MacDogPrivilegedHelper"))
        XCTAssertTrue(dryRun.contains("/Library/PrivilegedHelperTools/com.dhseo.macdog.helper"))
        XCTAssertTrue(dryRun.contains("set SleepDisabled 0/1"))
        XCTAssertTrue(dryRun.contains("set screenLock off/immediate/seconds only"))
    }
}
