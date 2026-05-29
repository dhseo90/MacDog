import AppKit
import Foundation

struct TabArt: Decodable {
    let module: String
    let resourceName: String
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
guard let dogSprite = NSImage(contentsOf: dogSourceURL) else {
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
    drawDog(item, sprite: dogSprite)
    drawTopicBadge(item)

    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

private func drawDog(_ item: TabArt, sprite: NSImage) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSBezierPath(ovalIn: NSRect(x: 61, y: 36, width: 150, height: 25))
    NSColor.black.withAlphaComponent(0.24).setFill()
    shadow.fill()

    let dogRect = NSRect(x: 56, y: 43, width: 150, height: 159)
    sprite.draw(in: dogRect, from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
}

private func drawTopicBadge(_ item: TabArt) {
    let shadow = NSBezierPath(ovalIn: NSRect(x: 28, y: 179, width: 62, height: 59))
    NSColor.black.withAlphaComponent(0.18).setFill()
    shadow.fill()

    let badgeRect = NSRect(x: 25, y: 183, width: 62, height: 59)
    let badge = NSBezierPath(ovalIn: badgeRect)
    (item.accentColor.blended(withFraction: 0.08, of: .white) ?? item.accentColor).setFill()
    badge.fill()

    NSColor.white.withAlphaComponent(0.30).setStroke()
    badge.lineWidth = 2
    badge.stroke()

    drawSymbol(
        item.topicSymbol,
        in: NSRect(x: 39, y: 197, width: 34, height: 32),
        color: NSColor.white.withAlphaComponent(0.98),
        shadowColor: NSColor.black.withAlphaComponent(0.18)
    )
}

private func drawButtonBackground(_ item: TabArt) {
    let glow = NSBezierPath(ovalIn: NSRect(x: 54, y: 32, width: 156, height: 34))
    item.accentColor.withAlphaComponent(0.20).setFill()
    glow.fill()
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
