import Foundation
import IOKit.ps

struct BatteryStatusSnapshot: Equatable {
    static let unavailable = BatteryStatusSnapshot(
        isPresent: false,
        percent: nil,
        isCharging: nil,
        isCharged: nil,
        isConnectedToPower: nil,
        timeToFullChargeMinutes: nil,
        timeToEmptyMinutes: nil,
        cycleCount: nil,
        temperatureCelsius: nil
    )

    let isPresent: Bool
    let percent: Int?
    let isCharging: Bool?
    let isCharged: Bool?
    let isConnectedToPower: Bool?
    let timeToFullChargeMinutes: Int?
    let timeToEmptyMinutes: Int?
    let cycleCount: Int?
    let temperatureCelsius: Double?

    static func capture() -> BatteryStatusSnapshot {
        guard
            let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return .unavailable
        }

        for source in sources {
            guard
                let description = IOPSGetPowerSourceDescription(info, source)?
                    .takeUnretainedValue() as? [String: Any],
                isInternalBattery(description)
            else {
                continue
            }

            return BatteryStatusSnapshot(description: description)
        }

        return .unavailable
    }

    var summary: String {
        guard isPresent else { return "배터리 없음" }

        let percentText = percent.map { "\($0)%" } ?? "비율 확인 불가"
        return "\(percentText) · \(stateLabel)"
    }

    var powerSummary: String {
        guard isPresent else { return "확인 불가" }

        if isConnectedToPower == true {
            if isCharged == true {
                return "전원 연결 · 충전 완료"
            }
            if let timeToFullChargeMinutes, timeToFullChargeMinutes > 0 {
                return "전원 연결 · 완충까지 \(Self.minutes(timeToFullChargeMinutes))"
            }
            return "전원 연결"
        }

        if let timeToEmptyMinutes, timeToEmptyMinutes > 0 {
            return "배터리 사용 · 남은 \(Self.minutes(timeToEmptyMinutes))"
        }
        return "배터리 사용"
    }

    var detailSummary: String {
        guard isPresent else { return "확인 불가" }
        var details: [String] = []
        if let cycleCount {
            details.append("사이클 \(cycleCount)")
        }
        if let temperatureCelsius {
            details.append("온도 \(String(format: "%.1f", temperatureCelsius))°C")
        }
        return details.isEmpty ? "세부 정보 없음" : details.joined(separator: " · ")
    }

    private init(description: [String: Any]) {
        let current = Self.intValue(description[kIOPSCurrentCapacityKey])
        let max = Self.intValue(description[kIOPSMaxCapacityKey])
        let percent = Self.percent(current: current, max: max)
        let powerSourceState = description[kIOPSPowerSourceStateKey] as? String

        self.isPresent = true
        self.percent = percent
        self.isCharging = Self.boolValue(description[kIOPSIsChargingKey])
        self.isCharged = Self.boolValue(description[kIOPSIsChargedKey])
        self.isConnectedToPower = powerSourceState == kIOPSACPowerValue
        self.timeToFullChargeMinutes = Self.positiveMinutes(description[kIOPSTimeToFullChargeKey])
        self.timeToEmptyMinutes = Self.positiveMinutes(description[kIOPSTimeToEmptyKey])
        self.cycleCount = Self.intValue(description["CycleCount"])
        self.temperatureCelsius = Self.temperatureCelsius(description["Temperature"])
    }

    init(
        isPresent: Bool,
        percent: Int?,
        isCharging: Bool?,
        isCharged: Bool?,
        isConnectedToPower: Bool?,
        timeToFullChargeMinutes: Int?,
        timeToEmptyMinutes: Int?,
        cycleCount: Int?,
        temperatureCelsius: Double?
    ) {
        self.isPresent = isPresent
        self.percent = percent
        self.isCharging = isCharging
        self.isCharged = isCharged
        self.isConnectedToPower = isConnectedToPower
        self.timeToFullChargeMinutes = timeToFullChargeMinutes
        self.timeToEmptyMinutes = timeToEmptyMinutes
        self.cycleCount = cycleCount
        self.temperatureCelsius = temperatureCelsius
    }

    private var stateLabel: String {
        if isCharged == true {
            return "충전 완료"
        }
        if isCharging == true {
            return "충전 중"
        }
        if isConnectedToPower == true {
            return "전원 연결"
        }
        return "방전 중"
    }

    private static func isInternalBattery(_ description: [String: Any]) -> Bool {
        if let type = description[kIOPSTypeKey] as? String, type == kIOPSInternalBatteryType {
            return true
        }

        return description[kIOPSCurrentCapacityKey] != nil && description[kIOPSMaxCapacityKey] != nil
    }

    private static func percent(current: Int?, max: Int?) -> Int? {
        guard let current, let max, max > 0 else { return nil }
        return Swift.min(Swift.max(Int((Double(current) / Double(max) * 100).rounded()), 0), 100)
    }

    private static func positiveMinutes(_ value: Any?) -> Int? {
        guard let minutes = intValue(value), minutes > 0 else { return nil }
        return minutes
    }

    private static func intValue(_ value: Any?) -> Int? {
        switch value {
        case let number as NSNumber:
            return number.intValue
        case let int as Int:
            return int
        default:
            return nil
        }
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        switch value {
        case let number as NSNumber:
            return number.boolValue
        case let bool as Bool:
            return bool
        default:
            return nil
        }
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            return number.doubleValue
        case let double as Double:
            return double
        case let int as Int:
            return Double(int)
        default:
            return nil
        }
    }

    private static func temperatureCelsius(_ value: Any?) -> Double? {
        guard let rawValue = doubleValue(value), rawValue > 0 else { return nil }
        let candidates = [
            rawValue / 100,
            rawValue / 10 - 273.15,
            rawValue - 273.15
        ]
        return candidates.first { (-20...120).contains($0) }
    }

    private static func minutes(_ value: Int) -> String {
        if value >= 60 {
            let hours = value / 60
            let minutes = value % 60
            return minutes == 0 ? "\(hours)시간" : "\(hours)시간 \(minutes)분"
        }

        return "\(value)분"
    }
}
