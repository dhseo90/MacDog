import AppKit
import Foundation

struct TabArt {
    let filename: String
    let topicSymbol: String
    let accent: NSColor
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputDirectory = root
    .appendingPathComponent("Sources", isDirectory: true)
    .appendingPathComponent("MacDog", isDirectory: true)
    .appendingPathComponent("Resources", isDirectory: true)
    .appendingPathComponent("PopoverTabs", isDirectory: true)
let dogSourceURL = root
    .appendingPathComponent("Sources", isDirectory: true)
    .appendingPathComponent("MacDog", isDirectory: true)
    .appendingPathComponent("Resources", isDirectory: true)
    .appendingPathComponent("DesktopPet", isDirectory: true)
    .appendingPathComponent("pup-idle-front-0.png")

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
guard let dogSprite = NSImage(contentsOf: dogSourceURL) else {
    fatalError("Missing Codex Pup desktop sprite: \(dogSourceURL.path)")
}

let artwork = [
    TabArt(filename: "codex-tab.png", topicSymbol: "chevron.left.forwardslash.chevron.right", accent: NSColor.systemBlue),
    TabArt(filename: "mac-tab.png", topicSymbol: "cpu", accent: NSColor.systemMint),
    TabArt(filename: "sleep-tab.png", topicSymbol: "moon.fill", accent: NSColor.systemIndigo),
    TabArt(filename: "battery-tab.png", topicSymbol: "battery.100percent", accent: NSColor.systemGreen)
]

for item in artwork {
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
    let shadow = NSBezierPath(ovalIn: NSRect(x: 70, y: 36, width: 134, height: 24))
    NSColor.black.withAlphaComponent(0.24).setFill()
    shadow.fill()

    let dogRect = NSRect(x: 72, y: 42, width: 142, height: 151)
    sprite.draw(in: dogRect, from: .zero, operation: .sourceOver, fraction: 1)

    fillRoundedRect(NSRect(x: 93, y: 46, width: 100, height: 12), radius: 6, color: item.accent.withAlphaComponent(0.86))
    NSGraphicsContext.restoreGraphicsState()
}

private func drawTopicBadge(_ item: TabArt) {
    let shadow = NSBezierPath(ovalIn: NSRect(x: 31, y: 172, width: 76, height: 72))
    NSColor.black.withAlphaComponent(0.22).setFill()
    shadow.fill()

    let badgeRect = NSRect(x: 28, y: 176, width: 76, height: 72)
    let badge = NSBezierPath(ovalIn: badgeRect)
    (item.accent.blended(withFraction: 0.08, of: .white) ?? item.accent).setFill()
    badge.fill()

    NSColor.white.withAlphaComponent(0.34).setStroke()
    badge.lineWidth = 3
    badge.stroke()

    drawSymbol(
        item.topicSymbol,
        in: NSRect(x: 43, y: 190, width: 46, height: 44),
        color: NSColor.white.withAlphaComponent(0.98),
        shadowColor: NSColor.black.withAlphaComponent(0.18)
    )
}

private func drawButtonBackground(_ item: TabArt) {
    let background = NSBezierPath(roundedRect: NSRect(x: 16, y: 16, width: 224, height: 224), xRadius: 38, yRadius: 38)
    let fill = item.accent.blended(withFraction: 0.88, of: NSColor(calibratedWhite: 0.18, alpha: 1)) ?? item.accent
    fill.withAlphaComponent(0.24).setFill()
    background.fill()

    item.accent.withAlphaComponent(0.20).setStroke()
    background.lineWidth = 4
    background.stroke()
}

private func fillRoundedRect(_ rect: NSRect, radius: CGFloat, color: NSColor) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    color.setFill()
    path.fill()
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
