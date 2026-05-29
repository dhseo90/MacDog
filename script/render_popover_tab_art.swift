import AppKit
import Foundation

struct TabArt: Decodable {
    let module: String
    let resourceName: String
    let sourcePose: String
    let resourcePrefix: String
    let sourceFrameIndex: Int
    let topicSymbol: String
    let accent: String

    var filename: String {
        "\(resourceName).png"
    }

    var accentColor: NSColor {
        switch accent {
        case "systemBlue":
            .systemBlue
        case "systemMint":
            .systemMint
        case "systemIndigo":
            .systemIndigo
        case "systemGreen":
            .systemGreen
        case "systemGray":
            .systemGray
        default:
            .controlAccentColor
        }
    }
}

struct TabArtManifest: Decodable {
    let characterId: String
    let desktopSource: DesktopSource
    let outputDirectory: String
    let tabs: [TabArt]
}

struct DesktopSource: Decodable {
    let resourceDirectory: String
    let sourcePose: String
    let resourcePrefix: String
    let sourceFrameIndex: Int
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let manifestURL = root
    .appendingPathComponent("Sources", isDirectory: true)
    .appendingPathComponent("MacDog", isDirectory: true)
    .appendingPathComponent("Resources", isDirectory: true)
    .appendingPathComponent("CharacterProfiles", isDirectory: true)
    .appendingPathComponent("codex-pup-tab-art.json")
let manifestData = try Data(contentsOf: manifestURL)
let manifest = try JSONDecoder().decode(TabArtManifest.self, from: manifestData)
let outputDirectory = root
    .appendingPathComponent("Sources", isDirectory: true)
    .appendingPathComponent("MacDog", isDirectory: true)
    .appendingPathComponent("Resources", isDirectory: true)
    .appendingPathComponent(manifest.outputDirectory, isDirectory: true)
let dogSourceURL = root
    .appendingPathComponent("Sources", isDirectory: true)
    .appendingPathComponent("MacDog", isDirectory: true)
    .appendingPathComponent("Resources", isDirectory: true)
    .appendingPathComponent(manifest.desktopSource.resourceDirectory, isDirectory: true)
    .appendingPathComponent("\(manifest.desktopSource.resourcePrefix)-\(manifest.desktopSource.sourceFrameIndex).png")

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
guard NSImage(contentsOf: dogSourceURL) != nil else {
    fatalError("Missing Codex Pup desktop sprite: \(dogSourceURL.path)")
}

for item in manifest.tabs {
    let bitmap = render(item)
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Failed to encode \(item.filename)")
    }

    try png.write(to: outputDirectory.appendingPathComponent(item.filename))
}

private func render(_ item: TabArt) -> NSBitmapImageRep {
    let size = NSSize(width: 256, height: 256)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width),
        pixelsHigh: Int(size.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Failed to allocate bitmap")
    }
    bitmap.size = size

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    NSColor.clear.setFill()
    NSRect(origin: .zero, size: size).fill()

    drawButtonBackground(item)
    drawDog(item)
    drawTopicBadge(item)

    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

private func drawDog(_ item: TabArt) {
    guard let sprite = dogSprite(for: item) else {
        fatalError("Missing Codex Pup tab sprite for \(item.module)")
    }

    NSGraphicsContext.saveGraphicsState()

    let contentRect = visibleContentRect(in: sprite)
    let dogRect = aspectFit(source: contentRect.size, in: dogBounds(for: item))
    let shadow = NSBezierPath(ovalIn: shadowRect(for: item, dogRect: dogRect))
    NSColor.black.withAlphaComponent(0.18).setFill()
    shadow.fill()

    sprite.draw(in: dogRect, from: contentRect, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
}

private func dogSprite(for item: TabArt) -> NSImage? {
    let url = root
        .appendingPathComponent("Sources", isDirectory: true)
        .appendingPathComponent("MacDog", isDirectory: true)
        .appendingPathComponent("Resources", isDirectory: true)
        .appendingPathComponent(manifest.desktopSource.resourceDirectory, isDirectory: true)
        .appendingPathComponent("\(item.resourcePrefix)-\(item.sourceFrameIndex).png")
    return NSImage(contentsOf: url)
}

private func dogBounds(for item: TabArt) -> NSRect {
    switch item.module {
    case "mac":
        NSRect(x: 4, y: 58, width: 242, height: 134)
    case "sleep":
        NSRect(x: 15, y: 44, width: 224, height: 128)
    case "battery":
        NSRect(x: 53, y: 28, width: 156, height: 172)
    case "settings":
        NSRect(x: 8, y: 54, width: 238, height: 140)
    default:
        NSRect(x: 28, y: 30, width: 178, height: 188)
    }
}

private func shadowRect(for item: TabArt, dogRect: NSRect) -> NSRect {
    switch item.module {
    case "mac":
        NSRect(x: dogRect.minX + 18, y: 30, width: dogRect.width - 24, height: 20)
    case "sleep":
        NSRect(x: dogRect.minX + 12, y: 38, width: dogRect.width - 14, height: 18)
    case "battery":
        NSRect(x: dogRect.minX + 30, y: 24, width: dogRect.width - 42, height: 24)
    case "settings":
        NSRect(x: dogRect.minX + 18, y: 43, width: dogRect.width - 30, height: 20)
    default:
        NSRect(x: dogRect.minX + 4, y: 23, width: dogRect.width - 10, height: 25)
    }
}

private func aspectFit(source: NSSize, in bounds: NSRect) -> NSRect {
    guard source.width > 0, source.height > 0 else { return bounds }

    let sourceRatio = source.width / source.height
    let boundsRatio = bounds.width / bounds.height
    var size = bounds.size

    if sourceRatio > boundsRatio {
        size.height = bounds.width / sourceRatio
    } else {
        size.width = bounds.height * sourceRatio
    }

    return NSRect(
        x: bounds.midX - size.width / 2,
        y: bounds.midY - size.height / 2,
        width: size.width,
        height: size.height
    )
}

private func drawTopicBadge(_ item: TabArt) {
    let shadow = NSBezierPath(ovalIn: NSRect(x: 184, y: 184, width: 54, height: 52))
    NSColor.black.withAlphaComponent(0.20).setFill()
    shadow.fill()

    let badgeRect = NSRect(x: 181, y: 190, width: 56, height: 54)
    let badge = NSBezierPath(ovalIn: badgeRect)
    (item.accentColor.blended(withFraction: 0.05, of: .white) ?? item.accentColor).setFill()
    badge.fill()

    NSColor.white.withAlphaComponent(0.34).setStroke()
    badge.lineWidth = 2.5
    badge.stroke()

    drawSymbol(
        item.topicSymbol,
        in: NSRect(x: 194, y: 204, width: 30, height: 28),
        color: NSColor.white.withAlphaComponent(0.98),
        shadowColor: NSColor.black.withAlphaComponent(0.18)
    )
}

private func drawButtonBackground(_ item: TabArt) {
    let glow = NSBezierPath(ovalIn: NSRect(x: 37, y: 20, width: 150, height: 21))
    item.accentColor.withAlphaComponent(0.10).setFill()
    glow.fill()
}

private func visibleContentRect(in image: NSImage) -> NSRect {
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff)
    else {
        return NSRect(origin: .zero, size: image.size)
    }

    var minX = bitmap.pixelsWide
    var minY = bitmap.pixelsHigh
    var maxX = 0
    var maxY = 0

    for y in 0..<bitmap.pixelsHigh {
        for x in 0..<bitmap.pixelsWide {
            guard let color = bitmap.colorAt(x: x, y: y), color.alphaComponent > 0.02 else {
                continue
            }

            minX = Swift.min(minX, x)
            minY = Swift.min(minY, y)
            maxX = Swift.max(maxX, x)
            maxY = Swift.max(maxY, y)
        }
    }

    guard minX <= maxX, minY <= maxY else {
        return NSRect(origin: .zero, size: image.size)
    }

    let padding = 2
    let x = Swift.max(0, minX - padding)
    let right = Swift.min(bitmap.pixelsWide, maxX + padding + 1)
    let top = Swift.max(0, minY - padding)
    let bottom = Swift.min(bitmap.pixelsHigh, maxY + padding + 1)
    let y = bitmap.pixelsHigh - bottom
    return NSRect(x: x, y: y, width: right - x, height: bottom - top)
}

private func drawSymbol(
    _ name: String,
    in rect: NSRect,
    color: NSColor,
    shadowColor: NSColor
) {
    guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil) else {
        return
    }

    let configuration = NSImage.SymbolConfiguration(pointSize: rect.height * 0.74, weight: .bold)
    let configured = symbol.withSymbolConfiguration(configuration) ?? symbol
    configured.isTemplate = true

    let shadowRect = rect.offsetBy(dx: 0, dy: -3)
    tinted(configured, color: shadowColor).draw(in: shadowRect, from: .zero, operation: .sourceOver, fraction: 1)
    tinted(configured, color: color).draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
}

private func tinted(_ image: NSImage, color: NSColor) -> NSImage {
    let copy = NSImage(size: image.size)
    copy.lockFocus()

    let rect = NSRect(origin: .zero, size: image.size)
    image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    color.setFill()
    rect.fill(using: .sourceAtop)

    copy.unlockFocus()
    return copy
}
