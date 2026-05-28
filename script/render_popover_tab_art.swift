import AppKit
import Foundation

struct TabArt {
    let filename: String
    let topicSymbol: String
    let accent: NSColor
    let earColor: NSColor
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputDirectory = root
    .appendingPathComponent("Sources", isDirectory: true)
    .appendingPathComponent("MacDog", isDirectory: true)
    .appendingPathComponent("Resources", isDirectory: true)
    .appendingPathComponent("PopoverTabs", isDirectory: true)

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let artwork = [
    TabArt(filename: "codex-tab.png", topicSymbol: "chevron.left.forwardslash.chevron.right", accent: NSColor.systemBlue, earColor: NSColor(calibratedRed: 0.72, green: 0.47, blue: 0.27, alpha: 1)),
    TabArt(filename: "mac-tab.png", topicSymbol: "cpu", accent: NSColor.systemMint, earColor: NSColor(calibratedRed: 0.62, green: 0.43, blue: 0.28, alpha: 1)),
    TabArt(filename: "sleep-tab.png", topicSymbol: "moon.fill", accent: NSColor.systemIndigo, earColor: NSColor(calibratedRed: 0.50, green: 0.39, blue: 0.34, alpha: 1)),
    TabArt(filename: "battery-tab.png", topicSymbol: "battery.100percent", accent: NSColor.systemGreen, earColor: NSColor(calibratedRed: 0.67, green: 0.46, blue: 0.30, alpha: 1))
]

for item in artwork {
    let image = render(item)
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        fatalError("Failed to encode \(item.filename)")
    }

    try png.write(to: outputDirectory.appendingPathComponent(item.filename))
}

private func render(_ item: TabArt) -> NSImage {
    let size = NSSize(width: 256, height: 256)
    let image = NSImage(size: size)
    image.lockFocus()

    NSColor.clear.setFill()
    NSRect(origin: .zero, size: size).fill()

    drawDog(item)
    drawTopicBadge(item)

    image.unlockFocus()
    return image
}

private func drawDog(_ item: TabArt) {
    NSGraphicsContext.saveGraphicsState()
    let scale: CGFloat = 0.66
    let anchor = NSPoint(x: 96, y: 42)
    let transform = NSAffineTransform()
    transform.translateX(by: anchor.x, yBy: anchor.y)
    transform.scale(by: scale)
    transform.translateX(by: -anchor.x, yBy: -anchor.y)
    transform.concat()

    drawDogShape(item)
    NSGraphicsContext.restoreGraphicsState()
}

private func drawDogShape(_ item: TabArt) {
    let shadow = NSBezierPath(ovalIn: NSRect(x: 36, y: 20, width: 184, height: 34))
    NSColor.black.withAlphaComponent(0.22).setFill()
    shadow.fill()

    fillRoundedRect(NSRect(x: 66, y: 28, width: 124, height: 72), radius: 40, color: NSColor(calibratedWhite: 0.93, alpha: 1))

    let leftEar = NSBezierPath()
    leftEar.move(to: NSPoint(x: 70, y: 166))
    leftEar.curve(to: NSPoint(x: 22, y: 72), controlPoint1: NSPoint(x: 24, y: 162), controlPoint2: NSPoint(x: 20, y: 102))
    leftEar.curve(to: NSPoint(x: 82, y: 82), controlPoint1: NSPoint(x: 32, y: 52), controlPoint2: NSPoint(x: 70, y: 54))
    leftEar.curve(to: NSPoint(x: 70, y: 166), controlPoint1: NSPoint(x: 96, y: 118), controlPoint2: NSPoint(x: 96, y: 154))
    item.earColor.setFill()
    leftEar.fill()

    let rightEar = NSBezierPath()
    rightEar.move(to: NSPoint(x: 186, y: 166))
    rightEar.curve(to: NSPoint(x: 234, y: 72), controlPoint1: NSPoint(x: 232, y: 162), controlPoint2: NSPoint(x: 236, y: 102))
    rightEar.curve(to: NSPoint(x: 174, y: 82), controlPoint1: NSPoint(x: 224, y: 52), controlPoint2: NSPoint(x: 186, y: 54))
    rightEar.curve(to: NSPoint(x: 186, y: 166), controlPoint1: NSPoint(x: 160, y: 118), controlPoint2: NSPoint(x: 160, y: 154))
    item.earColor.blended(withFraction: 0.10, of: .black)?.setFill()
    rightEar.fill()

    let face = NSBezierPath(ovalIn: NSRect(x: 42, y: 58, width: 172, height: 166))
    NSColor(calibratedWhite: 0.98, alpha: 1).setFill()
    face.fill()

    let forehead = NSBezierPath()
    forehead.move(to: NSPoint(x: 128, y: 220))
    forehead.curve(to: NSPoint(x: 104, y: 156), controlPoint1: NSPoint(x: 112, y: 202), controlPoint2: NSPoint(x: 100, y: 180))
    forehead.curve(to: NSPoint(x: 152, y: 156), controlPoint1: NSPoint(x: 114, y: 146), controlPoint2: NSPoint(x: 142, y: 146))
    forehead.curve(to: NSPoint(x: 128, y: 220), controlPoint1: NSPoint(x: 156, y: 180), controlPoint2: NSPoint(x: 144, y: 202))
    item.earColor.withAlphaComponent(0.22).setFill()
    forehead.fill()

    NSColor.black.withAlphaComponent(0.80).setFill()
    NSBezierPath(ovalIn: NSRect(x: 84, y: 139, width: 18, height: 22)).fill()
    NSBezierPath(ovalIn: NSRect(x: 154, y: 139, width: 18, height: 22)).fill()

    NSColor.white.withAlphaComponent(0.82).setFill()
    NSBezierPath(ovalIn: NSRect(x: 91, y: 153, width: 5, height: 6)).fill()
    NSBezierPath(ovalIn: NSRect(x: 161, y: 153, width: 5, height: 6)).fill()

    let muzzle = NSBezierPath(ovalIn: NSRect(x: 88, y: 86, width: 80, height: 56))
    NSColor(calibratedRed: 0.96, green: 0.91, blue: 0.84, alpha: 1).setFill()
    muzzle.fill()

    let nose = NSBezierPath(ovalIn: NSRect(x: 116, y: 116, width: 24, height: 18))
    NSColor.black.withAlphaComponent(0.84).setFill()
    nose.fill()

    let mouth = NSBezierPath()
    mouth.move(to: NSPoint(x: 128, y: 116))
    mouth.line(to: NSPoint(x: 128, y: 106))
    mouth.curve(to: NSPoint(x: 112, y: 103), controlPoint1: NSPoint(x: 124, y: 100), controlPoint2: NSPoint(x: 118, y: 98))
    mouth.move(to: NSPoint(x: 128, y: 106))
    mouth.curve(to: NSPoint(x: 144, y: 103), controlPoint1: NSPoint(x: 132, y: 100), controlPoint2: NSPoint(x: 138, y: 98))
    mouth.lineWidth = 5
    NSColor.black.withAlphaComponent(0.58).setStroke()
    mouth.stroke()

    fillRoundedRect(NSRect(x: 76, y: 44, width: 104, height: 16), radius: 8, color: item.accent.withAlphaComponent(0.92))

    let tag = NSBezierPath(ovalIn: NSRect(x: 108, y: 30, width: 40, height: 40))
    item.accent.blended(withFraction: 0.18, of: .black)?.setFill()
    tag.fill()
}

private func drawTopicBadge(_ item: TabArt) {
    let shadow = NSBezierPath(roundedRect: NSRect(x: 110, y: 124, width: 130, height: 108), xRadius: 30, yRadius: 30)
    NSColor.black.withAlphaComponent(0.34).setFill()
    shadow.fill()

    let badgeRect = NSRect(x: 104, y: 132, width: 130, height: 104)
    let badge = NSBezierPath(roundedRect: badgeRect, xRadius: 30, yRadius: 30)
    (item.accent.blended(withFraction: 0.08, of: .white) ?? item.accent).setFill()
    badge.fill()

    NSColor.white.withAlphaComponent(0.34).setStroke()
    badge.lineWidth = 4
    badge.stroke()

    drawSymbol(
        item.topicSymbol,
        in: NSRect(x: 128, y: 151, width: 84, height: 70),
        color: NSColor.white.withAlphaComponent(0.98),
        shadowColor: NSColor.black.withAlphaComponent(0.22)
    )
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
