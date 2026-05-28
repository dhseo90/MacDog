import Foundation
import MacDogPowerUIBridge

struct NativeChargeLimitState: Equatable {
    static let unavailable = NativeChargeLimitState(
        isSupported: false,
        availableLimits: [],
        currentLimitPercent: nil,
        errorMessage: nil
    )

    let isSupported: Bool
    let availableLimits: [Int]
    let currentLimitPercent: Int?
    let errorMessage: String?
}

struct NativeChargeLimitController {
    func readState() -> NativeChargeLimitState {
        var supportError: NSError?
        let isSupported = MDChargeLimitIsSupported(&supportError)
        if !isSupported {
            return NativeChargeLimitState(
                isSupported: false,
                availableLimits: [],
                currentLimitPercent: nil,
                errorMessage: supportError?.localizedDescription
            )
        }

        var limitsError: NSError?
        let availableLimits = (MDChargeLimitAvailableLimits(&limitsError) ?? [])
            .map(\.intValue)
            .filter { $0 >= RunnerPreferences.minimumChargeLimitTargetPercent && $0 <= RunnerPreferences.maximumChargeLimitTargetPercent }
            .sorted()

        var currentError: NSError?
        let currentLimit = MDChargeLimitCurrentLimit(&currentError)
        let currentLimitPercent = currentLimit >= 0 ? Int(currentLimit) : nil

        return NativeChargeLimitState(
            isSupported: true,
            availableLimits: availableLimits,
            currentLimitPercent: currentLimitPercent,
            errorMessage: limitsError?.localizedDescription ?? currentError?.localizedDescription
        )
    }

    func setLimitPercent(_ percent: Int) throws -> Int {
        let normalized = RunnerPreferences.normalizedChargeLimitTargetPercent(percent)
        var error: NSError?
        guard MDChargeLimitSetLimit(normalized, &error) else {
            throw error ?? NativeChargeLimitError.applyFailed
        }
        return normalized
    }
}

enum NativeChargeLimitError: LocalizedError {
    case applyFailed

    var errorDescription: String? {
        "충전 한도를 변경하지 못했습니다."
    }
}
