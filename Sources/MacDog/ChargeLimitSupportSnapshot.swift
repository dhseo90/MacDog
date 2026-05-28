import Darwin
import Foundation

struct ChargeLimitSupportSnapshot: Equatable {
    static let unavailable = ChargeLimitSupportSnapshot(
        operatingSystemVersion: ProcessInfo.processInfo.operatingSystemVersion,
        isAppleSilicon: false,
        nativeState: .unavailable
    )

    let operatingSystemVersion: OperatingSystemVersion
    let isAppleSilicon: Bool
    let nativeState: NativeChargeLimitState

    init(
        operatingSystemVersion: OperatingSystemVersion,
        isAppleSilicon: Bool,
        nativeState: NativeChargeLimitState = .unavailable
    ) {
        self.operatingSystemVersion = operatingSystemVersion
        self.isAppleSilicon = isAppleSilicon
        self.nativeState = nativeState
    }

    static func == (lhs: ChargeLimitSupportSnapshot, rhs: ChargeLimitSupportSnapshot) -> Bool {
        lhs.operatingSystemVersion.majorVersion == rhs.operatingSystemVersion.majorVersion &&
        lhs.operatingSystemVersion.minorVersion == rhs.operatingSystemVersion.minorVersion &&
        lhs.operatingSystemVersion.patchVersion == rhs.operatingSystemVersion.patchVersion &&
        lhs.isAppleSilicon == rhs.isAppleSilicon &&
        lhs.nativeState == rhs.nativeState
    }

    static func capture(controller: NativeChargeLimitController = NativeChargeLimitController()) -> ChargeLimitSupportSnapshot {
        let operatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion
        let isAppleSilicon = detectAppleSilicon()
        let osSupported = supportsNativeChargeLimitOS(operatingSystemVersion)
        return ChargeLimitSupportSnapshot(
            operatingSystemVersion: operatingSystemVersion,
            isAppleSilicon: isAppleSilicon,
            nativeState: isAppleSilicon && osSupported ? controller.readState() : .unavailable
        )
    }

    var isNativeChargeLimitAvailable: Bool {
        isAppleSilicon && supportsNativeChargeLimitOS && nativeState.isSupported
    }

    var currentLimitPercent: Int? {
        nativeState.currentLimitPercent
    }

    var availableLimits: [Int] {
        nativeState.availableLimits.isEmpty
            ? stride(
                from: RunnerPreferences.minimumChargeLimitTargetPercent,
                through: RunnerPreferences.maximumChargeLimitTargetPercent,
                by: RunnerPreferences.chargeLimitTargetStepPercent
            ).map { $0 }
            : nativeState.availableLimits
    }

    var summary: String {
        if isNativeChargeLimitAvailable {
            if let currentLimitPercent {
                return "시스템 한도 · \(currentLimitPercent)%"
            }
            return "시스템 제어 가능"
        }

        if !isAppleSilicon {
            return "미지원 · Apple silicon 필요"
        }

        if supportsNativeChargeLimitOS, let errorMessage = nativeState.errorMessage {
            return "확인 실패 · \(errorMessage)"
        }

        if supportsNativeChargeLimitOS {
            return "확인 실패"
        }

        return "미지원 · macOS 26.4+ 필요"
    }

    var requirementSummary: String {
        "macOS 26.4+ · Apple silicon"
    }

    private var supportsNativeChargeLimitOS: Bool {
        Self.supportsNativeChargeLimitOS(operatingSystemVersion)
    }

    private static func supportsNativeChargeLimitOS(_ version: OperatingSystemVersion) -> Bool {
        version.majorVersion > 26 ||
        (version.majorVersion == 26 && version.minorVersion >= 4)
    }

    private static func detectAppleSilicon() -> Bool {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let result = sysctlbyname("hw.optional.arm64", &value, &size, nil, 0)
        return result == 0 && value == 1
    }
}
