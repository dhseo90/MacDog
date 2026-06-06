import AppKit

struct MenuBarIconRenderer {
    static let imageSize = NSSize(width: 32, height: 21)

    static let frameCount = MacDogCharacterProfile.codexPup.desktopPet
        .asset(for: MacDogCharacterProfile.codexPup.menuBarImage.sourcePose)
        .frameCount

    private let profile: MacDogCharacterProfile
    private let sourceAsset: DesktopPetPoseAsset
    private let sourceLayout: SourceLayout?

    init(profile: MacDogCharacterProfile = .codexPup) {
        self.profile = profile
        self.sourceAsset = profile.desktopPet.asset(for: profile.menuBarImage.sourcePose)
        self.sourceLayout = Self.sourceLayout(profile: profile, sourceAsset: self.sourceAsset, targetSize: Self.imageSize)
    }

    func image(
        frame: Int,
        phase: UsagePressurePhase,
        reducedMotion: Bool = false
    ) -> NSImage {
        let renderedFrame = reducedMotion ? 0 : frame
        let frameIndex = renderedFrame % sourceAsset.frameCount
        let resourceName = "\(sourceAsset.resourcePrefix)-\(frameIndex)"

        guard let base = desktopPetImage(resourceName: resourceName) else {
            preconditionFailure("Missing menu bar image asset: \(resourceName).png")
        }

        return menuBarImage(from: base, phase: phase)
    }

    private func desktopPetImage(resourceName: String) -> NSImage? {
        Self.desktopPetImage(profile: profile, resourceName: resourceName)
    }

    private static func desktopPetImage(profile: MacDogCharacterProfile, resourceName: String) -> NSImage? {
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

    private struct SourceLayout {
        let scale: CGFloat
        let baseline: CGFloat
    }

    private static func sourceLayout(
        profile: MacDogCharacterProfile,
        sourceAsset: DesktopPetPoseAsset,
        targetSize: NSSize
    ) -> SourceLayout? {
        var unionRect: NSRect?
        var imageBounds: NSRect?

        for frameIndex in 0..<sourceAsset.frameCount {
            let resourceName = "\(sourceAsset.resourcePrefix)-\(frameIndex)"
            guard let image = desktopPetImage(profile: profile, resourceName: resourceName) else {
                continue
            }

            let bounds = NSRect(origin: .zero, size: image.size)
            imageBounds = bounds
            let frameRect = visibleContentRect(in: image)
                .insetBy(dx: -2, dy: -2)
                .intersection(bounds)
            unionRect = unionRect.map { $0.union(frameRect) } ?? frameRect
        }

        guard let unionRect, let imageBounds else { return nil }
        let stableRect = expand(unionRect, toAspectRatio: targetSize.width / targetSize.height, within: imageBounds)
        let scale = min(targetSize.width / stableRect.width, targetSize.height / stableRect.height)
        return SourceLayout(
            scale: scale,
            baseline: (unionRect.minY - stableRect.minY) * scale
        )
    }

    private static func expand(_ rect: NSRect, toAspectRatio aspectRatio: CGFloat, within bounds: NSRect) -> NSRect {
        var expanded = rect
        let center = NSPoint(x: rect.midX, y: rect.midY)

        if expanded.width / expanded.height < aspectRatio {
            expanded.size.width = expanded.height * aspectRatio
        } else {
            expanded.size.height = expanded.width / aspectRatio
        }

        expanded.origin = NSPoint(
            x: center.x - expanded.width / 2,
            y: center.y - expanded.height / 2
        )

        if expanded.minX < bounds.minX {
            expanded.origin.x = bounds.minX
        }
        if expanded.maxX > bounds.maxX {
            expanded.origin.x = bounds.maxX - expanded.width
        }
        if expanded.minY < bounds.minY {
            expanded.origin.y = bounds.minY
        }
        if expanded.maxY > bounds.maxY {
            expanded.origin.y = bounds.maxY - expanded.height
        }

        return expanded.intersection(bounds)
    }

    private func menuBarImage(from base: NSImage, phase: UsagePressurePhase) -> NSImage {
        let size = Self.imageSize
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        let sourceRect = Self.visibleContentRect(in: base)
            .insetBy(dx: -2, dy: -2)
            .intersection(NSRect(origin: .zero, size: base.size))
        let drawRect: NSRect
        if let sourceLayout {
            let drawSize = NSSize(
                width: sourceRect.width * sourceLayout.scale,
                height: sourceRect.height * sourceLayout.scale
            )
            drawRect = NSRect(
                x: (size.width - drawSize.width) / 2,
                y: sourceLayout.baseline,
                width: drawSize.width,
                height: drawSize.height
            )
        } else {
            drawRect = NSRect(origin: .zero, size: size)
        }
        base.draw(
            in: drawRect,
            from: sourceRect,
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

    private static func visibleContentRect(in image: NSImage) -> NSRect {
        guard
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff)
        else {
            return NSRect(origin: .zero, size: image.size)
        }

        var minX = bitmap.pixelsWide
        var minY = bitmap.pixelsHigh
        var maxX = -1
        var maxY = -1

        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                guard let color = bitmap.colorAt(x: x, y: y), color.alphaComponent > 0.02 else {
                    continue
                }
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard maxX >= minX, maxY >= minY else {
            return NSRect(origin: .zero, size: image.size)
        }

        let scaleX = image.size.width / CGFloat(bitmap.pixelsWide)
        let scaleY = image.size.height / CGFloat(bitmap.pixelsHigh)
        let width = CGFloat(maxX - minX + 1) * scaleX
        let height = CGFloat(maxY - minY + 1) * scaleY
        let originY = image.size.height - CGFloat(maxY + 1) * scaleY

        return NSRect(
            x: CGFloat(minX) * scaleX,
            y: originY,
            width: width,
            height: height
        )
    }

    private func drawLimitBadge(size: NSSize) {
        let badgeRect = NSRect(x: size.width - 8, y: size.height - 8, width: 6, height: 6)
        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: badgeRect).fill()
    }
}
