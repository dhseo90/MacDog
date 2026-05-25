import AppKit
import SwiftUI

struct RunnerIconRenderer {
    static let frameCount = 8

    func image(frame: Int, phase: UsagePressurePhase) -> NSImage {
        let size = NSSize(width: 22, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        let color = color(for: phase)
        color.setStroke()
        color.setFill()

        let stride = CGFloat(frame % Self.frameCount) / CGFloat(Self.frameCount)
        let lean = sin(stride * .pi * 2) * 2.4
        let foot = cos(stride * .pi * 2) * 3.4

        let body = NSBezierPath()
        body.lineWidth = 1.8
        body.lineCapStyle = .round
        body.move(to: NSPoint(x: 11 + lean, y: 12.5))
        body.line(to: NSPoint(x: 10 - lean * 0.4, y: 8.0))
        body.stroke()

        NSBezierPath(ovalIn: NSRect(x: 8.5 + lean, y: 13.2, width: 4.0, height: 4.0)).fill()

        let arms = NSBezierPath()
        arms.lineWidth = 1.5
        arms.lineCapStyle = .round
        arms.move(to: NSPoint(x: 10.5, y: 10.8))
        arms.line(to: NSPoint(x: 6.7 - foot * 0.25, y: 9.3))
        arms.move(to: NSPoint(x: 10.5, y: 10.8))
        arms.line(to: NSPoint(x: 14.8 + foot * 0.25, y: 11.3))
        arms.stroke()

        let legs = NSBezierPath()
        legs.lineWidth = 1.7
        legs.lineCapStyle = .round
        legs.move(to: NSPoint(x: 10, y: 8.0))
        legs.line(to: NSPoint(x: 6.4 + foot, y: 3.0))
        legs.move(to: NSPoint(x: 10, y: 8.0))
        legs.line(to: NSPoint(x: 14.7 - foot, y: 3.2))
        legs.stroke()

        if phase == .limit {
            NSColor.systemRed.setStroke()
            let warning = NSBezierPath()
            warning.lineWidth = 1.5
            warning.move(to: NSPoint(x: 18, y: 14))
            warning.line(to: NSPoint(x: 18, y: 7))
            warning.move(to: NSPoint(x: 18, y: 4))
            warning.line(to: NSPoint(x: 18, y: 3.8))
            warning.stroke()
        }

        image.unlockFocus()
        image.isTemplate = phase == .calm || phase == .active
        return image
    }

    private func color(for phase: UsagePressurePhase) -> NSColor {
        switch phase {
        case .calm:
            .labelColor
        case .active:
            .controlAccentColor
        case .fast:
            .systemOrange
        case .sprint:
            .systemRed
        case .limit:
            .systemRed
        }
    }
}

