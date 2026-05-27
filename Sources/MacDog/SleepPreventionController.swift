import Foundation
import IOKit.pwr_mgt

struct SleepPreventionStatus: Equatable {
    static let disabled = SleepPreventionStatus(
        isEnabled: false,
        isActive: false,
        endsAt: nil,
        errorMessage: nil
    )

    let isEnabled: Bool
    let isActive: Bool
    let endsAt: Date?
    let errorMessage: String?

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

final class SleepPreventionController {
    private static let requiredAssertions: [SleepPreventionAssertionKind] = [
        .displaySleep,
        .systemSleep
    ]

    private let assertionManager: PowerAssertionManaging
    private var assertionIDs: [SleepPreventionAssertionKind: IOPMAssertionID] = [:]
    private var requestedEnabled = false
    private var endsAt: Date?
    private var lastErrorMessage: String?

    init(assertionManager: PowerAssertionManaging = IOKitPowerAssertionManager()) {
        self.assertionManager = assertionManager
    }

    deinit {
        releaseAssertions()
    }

    var status: SleepPreventionStatus {
        SleepPreventionStatus(
            isEnabled: requestedEnabled,
            isActive: hasRequiredAssertions,
            endsAt: endsAt,
            errorMessage: lastErrorMessage
        )
    }

    func setEnabled(_ isEnabled: Bool, endsAt: Date?) {
        requestedEnabled = isEnabled
        self.endsAt = endsAt

        if isEnabled {
            acquireAssertionsIfNeeded()
        } else {
            releaseAssertions()
            self.endsAt = nil
            lastErrorMessage = nil
        }
    }

    private var hasRequiredAssertions: Bool {
        Self.requiredAssertions.allSatisfy { assertionIDs[$0] != nil }
    }

    private func acquireAssertionsIfNeeded() {
        guard !hasRequiredAssertions else {
            lastErrorMessage = nil
            return
        }

        for kind in Self.requiredAssertions where assertionIDs[kind] == nil {
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

    var assertionType: CFString {
        switch self {
        case .displaySleep:
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString
        case .systemSleep:
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString
        }
    }

    var reason: CFString {
        switch self {
        case .displaySleep:
            "MacDog display sleep prevention" as CFString
        case .systemSleep:
            "MacDog system sleep prevention" as CFString
        }
    }

    var errorLabel: String {
        switch self {
        case .displaySleep:
            "display"
        case .systemSleep:
            "system"
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
