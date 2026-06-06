import AppKit

struct MenuBarIconRenderer {
    static let frameCount = MacDogCharacterProfile.codexPup.desktopPet
        .asset(for: MacDogCharacterProfile.codexPup.menuBarImage.sourcePose)
        .frameCount

    private let profile: MacDogCharacterProfile

    init(profile: MacDogCharacterProfile = .codexPup) {
        self.profile = profile
    }

    func image(
        frame: Int,
        phase: UsagePressurePhase,
        reducedMotion: Bool = false
    ) -> NSImage {
        let sourcePose = profile.menuBarImage.sourcePose
        let sourceAsset = profile.desktopPet.asset(for: sourcePose)
        let renderedFrame = reducedMotion ? 0 : frame
        let frameIndex = renderedFrame % sourceAsset.frameCount
        let resourceName = "\(sourceAsset.resourcePrefix)-\(frameIndex)"

        guard let base = desktopPetImage(resourceName: resourceName) else {
            preconditionFailure("Missing menu bar image asset: \(resourceName).png")
        }

        return menuBarImage(from: base, phase: phase)
    }

    private func desktopPetImage(resourceName: String) -> NSImage? {
        let directory = profile.desktopPet.resourceDirectory
        if let mainResourceURL = Bundle.main.resourceURL?
            .appendingPathComponent(directory, isDirectory: true)
            .appendingPathComponent("\(resourceName).png"),
            let image = NSImage(contentsOf: mainResourceURL) {
            return image
        }

        if let mainResourceURL = Bundle.main.resourceURL?.appendingPathComponent("\(resourceName).png"),
           let image = NSImage(contentsOf: mainResourceURL) {
            return image
        }

        if let url = Bundle.module.url(
            forResource: resourceName,
            withExtension: "png",
            subdirectory: directory
        ) {
            return NSImage(contentsOf: url)
        }

        guard let url = Bundle.module.url(forResource: resourceName, withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    private func menuBarImage(from base: NSImage, phase: UsagePressurePhase) -> NSImage {
        let size = NSSize(width: 28, height: 24)
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        let scale = min(size.width / base.size.width, size.height / base.size.height)
        let drawSize = NSSize(width: base.size.width * scale, height: base.size.height * scale)
        let drawRect = NSRect(
            x: (size.width - drawSize.width) / 2,
            y: (size.height - drawSize.height) / 2,
            width: drawSize.width,
            height: drawSize.height
        )
        base.draw(
            in: drawRect,
            from: NSRect(origin: .zero, size: base.size),
            operation: .sourceOver,
            fraction: 1.0
        )

        if phase == .limit {
            drawLimitBadge(size: size)
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func drawLimitBadge(size: NSSize) {
        let badgeRect = NSRect(x: size.width - 8, y: size.height - 8, width: 6, height: 6)
        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: badgeRect).fill()
    }
}
