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

    var guidanceSummary: String {
        if isNativeChargeLimitAvailable {
            return "목표보다 높으면 강제 방전하지 않고 충전을 멈춘 뒤 자연 하강합니다."
        }

        if !isAppleSilicon {
            return "이 Mac은 앱 제어를 지원하지 않아 배터리 설정에서 확인해야 합니다."
        }

        if !supportsNativeChargeLimitOS {
            return "macOS 26.4 이상에서 앱 제어가 가능하며, 현재는 배터리 설정에서 확인하세요."
        }

        return "앱에서 충전 한도를 확인하지 못했습니다. 배터리 설정에서 직접 확인하세요."
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
