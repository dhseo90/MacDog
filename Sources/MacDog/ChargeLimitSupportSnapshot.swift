import Darwin
import Foundation

struct ChargeLimitSupportSnapshot: Equatable {
    static let unavailable = ChargeLimitSupportSnapshot(
        operatingSystemVersion: ProcessInfo.processInfo.operatingSystemVersion,
        isAppleSilicon: false
    )

    let operatingSystemVersion: OperatingSystemVersion
    let isAppleSilicon: Bool

    static func == (lhs: ChargeLimitSupportSnapshot, rhs: ChargeLimitSupportSnapshot) -> Bool {
        lhs.operatingSystemVersion.majorVersion == rhs.operatingSystemVersion.majorVersion &&
        lhs.operatingSystemVersion.minorVersion == rhs.operatingSystemVersion.minorVersion &&
        lhs.operatingSystemVersion.patchVersion == rhs.operatingSystemVersion.patchVersion &&
        lhs.isAppleSilicon == rhs.isAppleSilicon
    }

    static func capture() -> ChargeLimitSupportSnapshot {
        ChargeLimitSupportSnapshot(
            operatingSystemVersion: ProcessInfo.processInfo.operatingSystemVersion,
            isAppleSilicon: detectAppleSilicon()
        )
    }

    var isNativeChargeLimitAvailable: Bool {
        isAppleSilicon && supportsNativeChargeLimitOS
    }

    var summary: String {
        if isNativeChargeLimitAvailable {
            return "지원 가능 · 80~100%"
        }

        if !isAppleSilicon {
            return "미지원 · Apple silicon 필요"
        }

        return "미지원 · macOS 26.4+ 필요"
    }

    var requirementSummary: String {
        "macOS 26.4+ · Apple silicon"
    }

    private var supportsNativeChargeLimitOS: Bool {
        operatingSystemVersion.majorVersion > 26 ||
        (operatingSystemVersion.majorVersion == 26 && operatingSystemVersion.minorVersion >= 4)
    }

    private static func detectAppleSilicon() -> Bool {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let result = sysctlbyname("hw.optional.arm64", &value, &size, nil, 0)
        return result == 0 && value == 1
    }
}
