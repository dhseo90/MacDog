enum PetAction: Equatable {
    case showUsageDetails
    case refreshNow
    case setDisplayBasis(UsageDisplayBasis)
    case setReducedMotion(Bool)
    case setAnimationPaused(Bool)
    case showDesktopPet
    case returnToMenuBar
    case quit
}

enum PetSurface: Equatable {
    case menuBar
    case desktop
}
