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
    private var assertionID: IOPMAssertionID?
    private var requestedEnabled = false
    private var endsAt: Date?
    private var lastErrorMessage: String?

    deinit {
        releaseAssertion()
    }

    var status: SleepPreventionStatus {
        SleepPreventionStatus(
            isEnabled: requestedEnabled,
            isActive: assertionID != nil,
            endsAt: endsAt,
            errorMessage: lastErrorMessage
        )
    }

    func setEnabled(_ isEnabled: Bool, endsAt: Date?) {
        requestedEnabled = isEnabled
        self.endsAt = endsAt

        if isEnabled {
            acquireAssertionIfNeeded()
        } else {
            releaseAssertion()
            self.endsAt = nil
            lastErrorMessage = nil
        }
    }

    private func acquireAssertionIfNeeded() {
        guard assertionID == nil else {
            lastErrorMessage = nil
            return
        }

        var newAssertionID = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "MacDog sleep prevention" as CFString,
            &newAssertionID
        )

        if result == kIOReturnSuccess {
            assertionID = newAssertionID
            lastErrorMessage = nil
        } else {
            lastErrorMessage = "IOKit \(result)"
        }
    }

    private func releaseAssertion() {
        guard let assertionID else { return }
        IOPMAssertionRelease(assertionID)
        self.assertionID = nil
    }
}
