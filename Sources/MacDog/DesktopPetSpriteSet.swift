import AppKit

struct DesktopPetSpriteSet {
    private let frameCache: [DesktopPetPose: DesktopPetAnimation]

    init(profile: MacDogCharacterProfile = .codexPup) {
        self.frameCache = Dictionary(
            uniqueKeysWithValues: DesktopPetPose.allCases.map { pose in
                let asset = profile.desktopPet.asset(for: pose)
                return (
                    pose,
                    Self.loadFrames(
                        prefix: asset.resourcePrefix,
                        count: asset.frameCount,
                        resourceDirectory: profile.desktopPet.resourceDirectory
                    )
                )
            }
        )
    }

    func frame(pose: DesktopPetPose, frame: Int, flipped: Bool = false) -> DesktopPetFrame? {
        guard let frames = frameCache[pose], !frames.isEmpty else { return nil }
        let selectedFrames = flipped ? frames.flipped : frames.regular
        return selectedFrames[frame % selectedFrames.count]
    }

    private static func loadFrames(prefix: String, count: Int, resourceDirectory: String) -> DesktopPetAnimation {
        let images = (0..<count).compactMap { index in
            loadImage(named: "\(prefix)-\(index)", resourceDirectory: resourceDirectory)
        }
        let regular = horizontallyAlignedFrames(from: images)
        let flipped = regular.map { $0.horizontallyFlipped() }
        return DesktopPetAnimation(regular: regular, flipped: flipped)
    }

    private static func loadImage(named name: String, resourceDirectory: String) -> NSImage? {
        if let url = Bundle.main.resourceURL?
            .appendingPathComponent(resourceDirectory, isDirectory: true)
            .appendingPathComponent("\(name).png") {
            return NSImage(contentsOf: url)
        }

        if let url = Bundle.module.url(
            forResource: name,
            withExtension: "png",
            subdirectory: resourceDirectory
        ) {
            return NSImage(contentsOf: url)
        }

        return nil
    }

    private static func horizontallyAlignedFrames(from images: [NSImage]) -> [DesktopPetFrame] {
        let centers = images.map { opaqueBoundsCenterX(for: $0) }
        let referenceCenter = median(centers.compactMap(\.self))

        return zip(images, centers).map { image, center in
            let offsetX = center.map { referenceCenter - $0 } ?? 0
            return DesktopPetFrame(image: image, offset: NSPoint(x: offsetX, y: 0))
        }
    }

    private static func opaqueBoundsCenterX(for image: NSImage) -> CGFloat? {
        var rect = NSRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard
            let context = CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width
        var maxX = -1
        for y in 0..<height {
            let rowStart = y * bytesPerRow
            for x in 0..<width {
                let alpha = pixels[rowStart + x * bytesPerPixel + 3]
                guard alpha > 20 else { continue }
                minX = min(minX, x)
                maxX = max(maxX, x)
            }
        }

        guard maxX >= minX else { return nil }
        return CGFloat(minX + maxX) / 2
    }

    private static func median(_ values: [CGFloat]) -> CGFloat {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let midpoint = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[midpoint - 1] + sorted[midpoint]) / 2
        }
        return sorted[midpoint]
    }
}

enum DesktopPetPose: CaseIterable, Equatable {
    case runRight
    case runUp
    case runDown
    case idleFront
    case idleSide
    case rest
    case alert

    var resourcePrefix: String {
        MacDogCharacterProfile.codexPup.desktopPet.asset(for: self).resourcePrefix
    }

    var frameCount: Int {
        MacDogCharacterProfile.codexPup.desktopPet.asset(for: self).frameCount
    }
}

struct DesktopPetAnimation {
    let regular: [DesktopPetFrame]
    let flipped: [DesktopPetFrame]

    var isEmpty: Bool {
        regular.isEmpty
    }
}

struct DesktopPetFrame {
    let image: NSImage
    let offset: NSPoint

    func horizontallyFlipped() -> DesktopPetFrame {
        DesktopPetFrame(
            image: image.horizontallyFlipped(),
            offset: NSPoint(x: -offset.x, y: offset.y)
        )
    }
}

private extension NSImage {
    func horizontallyFlipped() -> NSImage {
        let flipped = NSImage(size: size)
        flipped.lockFocus()

        let transform = NSAffineTransform()
        transform.translateX(by: size.width, yBy: 0)
        transform.scaleX(by: -1, yBy: 1)
        transform.concat()

        draw(in: NSRect(origin: .zero, size: size))
        flipped.unlockFocus()
        flipped.isTemplate = isTemplate
        return flipped
    }
}
