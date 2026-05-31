import Foundation
import IOKit.pwr_mgt

struct SleepPreventionStatus: Equatable {
    static let disabled = SleepPreventionStatus(
        isEnabled: false,
        isActive: false,
        endsAt: nil,
        isClosedLidSleepDisabled: false,
        isScreenLockDisabled: false,
        errorMessage: nil,
        closedLidWarningMessage: nil,
        screenLockWarningMessage: nil
    )

    let isEnabled: Bool
    let isActive: Bool
    let endsAt: Date?
    let isClosedLidSleepDisabled: Bool
    let isScreenLockDisabled: Bool
    let errorMessage: String?
    let closedLidWarningMessage: String?
    let screenLockWarningMessage: String?

    var summary: String {
        if isActive {
            if let endsAt {
                return "켜짐 · \(endsAt.formatted(date: .omitted, time: .shortened))까지"
            }
            return "켜짐 · 계속"
        }
        if let errorMessage {
            return "오류 · \(errorMessage)"
        }
        return isEnabled ? "켜짐 · 대기 중" : "꺼짐"
    }
}

struct SleepPreventionPolicy: Equatable {
    static let `default` = SleepPreventionPolicy(
        preventDisplaySleep: true,
        preventClosedLidSleep: true,
        disableScreenLock: true
    )

    let preventDisplaySleep: Bool
    let preventClosedLidSleep: Bool
    let disableScreenLock: Bool

    var requiredAssertions: [SleepPreventionAssertionKind] {
        var assertions: [SleepPreventionAssertionKind] = []
        if preventDisplaySleep {
            assertions.append(.displaySleep)
        }
        assertions.append(.systemSleep)
        if preventClosedLidSleep {
            assertions.append(.networkClient)
        }
        return assertions
    }
}

final class SleepPreventionController {
    private let assertionManager: PowerAssertionManaging
    private let closedLidSleepDisabler: ClosedLidSleepDisabling
    private let screenLockDisabler: ScreenLockDisabling
    private var assertionIDs: [SleepPreventionAssertionKind: IOPMAssertionID] = [:]
    private var policy: SleepPreventionPolicy = .default
    private var requestedEnabled = false
    private var closedLidDisableAttempted = false
    private var screenLockDisableAttempted = false
    private var isClosedLidSleepDisabled = false
    private var isScreenLockDisabled = false
    private var endsAt: Date?
    private var lastErrorMessage: String?
    private var lastClosedLidWarningMessage: String?
    private var lastScreenLockWarningMessage: String?

    init(
        assertionManager: PowerAssertionManaging = IOKitPowerAssertionManager(),
        closedLidSleepDisabler: ClosedLidSleepDisabling = PMSetClosedLidSleepDisabler(),
        screenLockDisabler: ScreenLockDisabling = ScreenSaverLockDisabler()
    ) {
        self.assertionManager = assertionManager
        self.closedLidSleepDisabler = closedLidSleepDisabler
        self.screenLockDisabler = screenLockDisabler
    }

    deinit {
        releaseAssertions()
    }

    var status: SleepPreventionStatus {
        SleepPreventionStatus(
            isEnabled: requestedEnabled,
            isActive: hasRequiredAssertions,
            endsAt: endsAt,
            isClosedLidSleepDisabled: isClosedLidSleepDisabled,
            isScreenLockDisabled: isScreenLockDisabled,
            errorMessage: lastErrorMessage,
            closedLidWarningMessage: lastClosedLidWarningMessage,
            screenLockWarningMessage: lastScreenLockWarningMessage
        )
    }

    func setEnabled(_ isEnabled: Bool, endsAt: Date?, policy: SleepPreventionPolicy = .default) {
        requestedEnabled = isEnabled
        self.endsAt = endsAt
        self.policy = policy

        if isEnabled {
            acquireAssertionsIfNeeded()
            guard hasRequiredAssertions else { return }
            syncClosedLidSleepPolicy()
            syncScreenLockPolicy()
            clearErrorIfPolicyIsSatisfied()
        } else {
            restoreScreenLockIfNeeded(force: true)
            restoreClosedLidSleepIfNeeded(force: true)
            releaseAssertions()
            self.endsAt = nil
            lastErrorMessage = nil
            lastClosedLidWarningMessage = nil
            lastScreenLockWarningMessage = nil
            closedLidDisableAttempted = false
            screenLockDisableAttempted = false
        }
    }

    private var hasRequiredAssertions: Bool {
        policy.requiredAssertions.allSatisfy { assertionIDs[$0] != nil }
    }

    private func acquireAssertionsIfNeeded() {
        releaseAssertionsNoLongerRequired()

        guard !hasRequiredAssertions else {
            return
        }

        for kind in policy.requiredAssertions where assertionIDs[kind] == nil {
            let (result, assertionID) = assertionManager.createAssertion(
                type: kind.assertionType,
                reason: kind.reason
            )

            guard result == kIOReturnSuccess else {
                lastErrorMessage = "\(kind.errorLabel) IOKit \(result)"
                releaseAssertions()
                return
            }

            assertionIDs[kind] = assertionID
        }

        lastErrorMessage = nil
    }

    private func releaseAssertionsNoLongerRequired() {
        let requiredAssertions = Set(policy.requiredAssertions)
        let obsoleteAssertions = assertionIDs.filter { kind, _ in !requiredAssertions.contains(kind) }
        for (kind, assertionID) in obsoleteAssertions {
            assertionManager.releaseAssertion(assertionID)
            assertionIDs.removeValue(forKey: kind)
        }
    }

    private func syncClosedLidSleepPolicy() {
        if policy.preventClosedLidSleep {
            disableClosedLidSleepIfNeeded()
        } else {
            restoreClosedLidSleepIfNeeded()
            closedLidDisableAttempted = false
        }
    }

    private func disableClosedLidSleepIfNeeded() {
        guard !isClosedLidSleepDisabled else { return }
        guard !closedLidDisableAttempted || closedLidSleepDisabler.canRetryWithoutUserApproval else {
            return
        }
        closedLidDisableAttempted = true

        do {
            isClosedLidSleepDisabled = try closedLidSleepDisabler.setClosedLidSleepDisabled(true)
            lastClosedLidWarningMessage = nil
        } catch {
            isClosedLidSleepDisabled = false
            lastClosedLidWarningMessage = error.localizedDescription
        }
    }

    private func syncScreenLockPolicy() {
        if policy.disableScreenLock {
            disableScreenLockIfNeeded()
        } else {
            restoreScreenLockIfNeeded()
            screenLockDisableAttempted = false
        }
    }

    private func disableScreenLockIfNeeded() {
        guard !isScreenLockDisabled else { return }
        screenLockDisableAttempted = true

        do {
            isScreenLockDisabled = try screenLockDisabler.setScreenLockDisabled(true)
            lastScreenLockWarningMessage = nil
        } catch {
            isScreenLockDisabled = false
            lastScreenLockWarningMessage = error.localizedDescription
        }
    }

    private func clearErrorIfPolicyIsSatisfied() {
        guard hasRequiredAssertions else { return }
        lastErrorMessage = nil
    }

    private func restoreClosedLidSleepIfNeeded(force: Bool = false) {
        guard force || closedLidDisableAttempted || isClosedLidSleepDisabled else { return }
        do {
            _ = try closedLidSleepDisabler.setClosedLidSleepDisabled(false)
            lastClosedLidWarningMessage = nil
        } catch {
            lastClosedLidWarningMessage = error.localizedDescription
        }
        isClosedLidSleepDisabled = false
    }

    private func restoreScreenLockIfNeeded(force: Bool = false) {
        guard force || screenLockDisableAttempted || isScreenLockDisabled else { return }
        do {
            _ = try screenLockDisabler.setScreenLockDisabled(false)
        } catch {
            lastScreenLockWarningMessage = error.localizedDescription
        }
        isScreenLockDisabled = false
    }

    private func releaseAssertions() {
        for assertionID in assertionIDs.values {
            assertionManager.releaseAssertion(assertionID)
        }
        assertionIDs.removeAll()
    }
}

enum SleepPreventionAssertionKind: Hashable {
    case displaySleep
    case systemSleep
    case networkClient

    var assertionType: CFString {
        switch self {
        case .displaySleep:
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString
        case .systemSleep:
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString
        case .networkClient:
            kIOPMAssertNetworkClientActive as CFString
        }
    }

    var reason: CFString {
        switch self {
        case .displaySleep:
            "MacDog display sleep prevention" as CFString
        case .systemSleep:
            "MacDog system sleep prevention" as CFString
        case .networkClient:
            "MacDog closed-display sleep prevention" as CFString
        }
    }

    var errorLabel: String {
        switch self {
        case .displaySleep:
            "display"
        case .systemSleep:
            "system"
        case .networkClient:
            "network"
        }
    }
}

protocol PowerAssertionManaging {
    func createAssertion(type: CFString, reason: CFString) -> (IOReturn, IOPMAssertionID)
    func releaseAssertion(_ assertionID: IOPMAssertionID)
}

struct IOKitPowerAssertionManager: PowerAssertionManaging {
    func createAssertion(type: CFString, reason: CFString) -> (IOReturn, IOPMAssertionID) {
        var assertionID = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            type,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )
        return (result, assertionID)
    }

    func releaseAssertion(_ assertionID: IOPMAssertionID) {
        IOPMAssertionRelease(assertionID)
    }
}
