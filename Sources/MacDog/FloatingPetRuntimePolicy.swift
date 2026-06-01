import Foundation

struct FloatingPetRuntimePolicy: Equatable {
    static let calmMotionTickInterval: TimeInterval = 1.0 / 20.0
    static let activeMotionTickInterval: TimeInterval = 1.0 / 24.0
    static let fastMotionTickInterval: TimeInterval = 1.0 / 30.0
    static let maximumTimerTolerance: TimeInterval = 0.08
    static let timerToleranceFraction = 0.25

    static func motionTickInterval(for phase: UsagePressurePhase) -> TimeInterval {
        switch phase {
        case .calm:
            return calmMotionTickInterval
        case .active:
            return activeMotionTickInterval
        case .fast, .sprint:
            return fastMotionTickInterval
        case .limit:
            return fastMotionTickInterval
        }
    }

    static func updateTimerInterval(
        canMove: Bool,
        phase: UsagePressurePhase,
        frameInterval: TimeInterval
    ) -> TimeInterval {
        canMove ? motionTickInterval(for: phase) : frameInterval
    }

    static func timerTolerance(for interval: TimeInterval) -> TimeInterval {
        min(interval * timerToleranceFraction, maximumTimerTolerance)
    }
}
