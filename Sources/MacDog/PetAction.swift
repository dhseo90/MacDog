enum PetAction: Equatable {
    case showUsageDetails
    case refreshNow
    case setDisplayBasis(UsageDisplayBasis)
    case setReducedMotion(Bool)
    case setAnimationPaused(Bool)
    case setSleepPreventionMode(SleepPreventionMode)
    case setSleepPreventionEnabled(Bool)
    case setSleepPreventionSessionPreset(SleepPreventionSessionPreset)
    case setSleepPreventionPowerAdapterTrigger(Bool)
    case setSleepPreventionCodexAppTrigger(Bool)
    case setSleepPreventionChargingBelowThresholdTrigger(Bool)
    case setSleepPreventionCPUThresholdTrigger(Bool)
    case setSleepPreventionNetworkActivityTrigger(Bool)
    case setSleepPreventionExternalVolumeTrigger(Bool)
    case setSleepPreventionPreventDisplaySleep(Bool)
    case setSleepPreventionPreventClosedLidSleep(Bool)
    case setSleepPreventionDisableScreenLock(Bool)
    case openBatterySettings
    case showDesktopPet
    case returnToMenuBar
    case quit
}

enum PetSurface: Equatable {
    case menuBar
    case desktop
}
