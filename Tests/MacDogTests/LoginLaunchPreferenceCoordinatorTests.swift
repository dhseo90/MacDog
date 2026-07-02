import XCTest
@testable import MacDog

final class LoginLaunchPreferenceCoordinatorTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "MacDogTests.LoginLaunchPreferenceCoordinator.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        RunnerPreferences.registerDefaults(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testEnableFailureStoresDisabledPreference() {
        RunnerPreferences.setLoginLaunchEnabled(true, defaults: defaults)
        let coordinator = LoginLaunchPreferenceCoordinator(defaults: defaults) { _ in
            throw LoginLaunchControllerError.loginItemUnavailable(.notFound)
        }

        XCTAssertThrowsError(try coordinator.setEnabled(true)) { error in
            XCTAssertEqual(error as? LoginLaunchControllerError, .loginItemUnavailable(.notFound))
        }
        XCTAssertFalse(RunnerPreferences.loginLaunchEnabled(defaults: defaults))
    }

    func testSuccessfulEnableStoresEnabledPreference() throws {
        RunnerPreferences.setLoginLaunchEnabled(false, defaults: defaults)
        let coordinator = LoginLaunchPreferenceCoordinator(defaults: defaults) { enabled in
            XCTAssertTrue(enabled)
        }

        try coordinator.setEnabled(true)

        XCTAssertTrue(RunnerPreferences.loginLaunchEnabled(defaults: defaults))
    }

    func testDisableFailureStoresEnabledPreference() {
        RunnerPreferences.setLoginLaunchEnabled(false, defaults: defaults)
        let coordinator = LoginLaunchPreferenceCoordinator(defaults: defaults) { _ in
            throw LoginLaunchControllerError.loginItemUnavailable(.unknown)
        }

        XCTAssertThrowsError(try coordinator.setEnabled(false))
        XCTAssertTrue(RunnerPreferences.loginLaunchEnabled(defaults: defaults))
    }
}
