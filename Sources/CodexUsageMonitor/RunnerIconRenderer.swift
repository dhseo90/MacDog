import AppKit
import SwiftUI

struct RunnerIconRenderer {
    static let frameCount = 8

    func image(
        frame: Int,
        phase: UsagePressurePhase,
        theme: RunnerTheme = .pup,
        reducedMotion: Bool = false
    ) -> NSImage {
        let size = NSSize(width: 22, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        let color = color(for: phase, theme: theme)
        color.setStroke()
        color.setFill()

        let renderedFrame = reducedMotion ? 0 : frame
        let stride = CGFloat(renderedFrame % Self.frameCount) / CGFloat(Self.frameCount)
        drawPup(frameStride: stride, phase: phase, color: color)

        if theme == .spark {
            drawSpark(frame: renderedFrame, phase: phase)
        } else if theme == .pulse {
            drawPulse(frame: renderedFrame, phase: phase, color: color)
        }

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

    private func color(for phase: UsagePressurePhase, theme: RunnerTheme) -> NSColor {
        switch phase {
        case .calm:
            theme == .pulse ? .systemTeal : .labelColor
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

    private func drawPup(frameStride: CGFloat, phase: UsagePressurePhase, color: NSColor) {
        let run = sin(frameStride * .pi * 2)
        let paw = cos(frameStride * .pi * 2)
        let bounce = phase == .calm ? run * 0.25 : abs(run) * 0.8
        let tailLift = run * 1.2

        let tail = NSBezierPath()
        tail.lineWidth = 1.6
        tail.lineCapStyle = .round
        tail.move(to: NSPoint(x: 6.8, y: 10.8 + bounce))
        tail.curve(
            to: NSPoint(x: 2.2, y: 13.2 + tailLift),
            controlPoint1: NSPoint(x: 5.1, y: 12.2 + tailLift),
            controlPoint2: NSPoint(x: 3.7, y: 13.6 + tailLift)
        )
        tail.stroke()

        NSBezierPath(roundedRect: NSRect(x: 6.0, y: 6.4 + bounce, width: 9.8, height: 6.5), xRadius: 3.2, yRadius: 3.0).fill()
        NSBezierPath(ovalIn: NSRect(x: 13.8, y: 9.2 + bounce, width: 5.5, height: 5.0)).fill()
        NSBezierPath(ovalIn: NSRect(x: 17.7, y: 9.6 + bounce, width: 3.0, height: 2.2)).fill()

        let ear = NSBezierPath()
        ear.move(to: NSPoint(x: 14.9, y: 13.2 + bounce))
        ear.line(to: NSPoint(x: 15.9 + paw * 0.25, y: 16.1 + bounce))
        ear.line(to: NSPoint(x: 17.4, y: 12.8 + bounce))
        ear.close()
        ear.fill()

        NSColor.controlBackgroundColor.withAlphaComponent(0.85).setFill()
        NSBezierPath(ovalIn: NSRect(x: 17.2, y: 12.1 + bounce, width: 0.9, height: 0.9)).fill()
        color.setStroke()
        color.setFill()

        let legs = NSBezierPath()
        legs.lineWidth = 1.4
        legs.lineCapStyle = .round
        drawLeg(path: legs, hipX: 8.0, hipY: 6.9 + bounce, footX: 6.4 + paw * 1.0, footY: 2.7)
        drawLeg(path: legs, hipX: 10.3, hipY: 6.8 + bounce, footX: 10.8 - paw * 1.1, footY: 2.8)
        drawLeg(path: legs, hipX: 13.4, hipY: 7.0 + bounce, footX: 12.4 - paw * 1.0, footY: 2.9)
        drawLeg(path: legs, hipX: 15.0, hipY: 7.2 + bounce, footX: 16.3 + paw * 1.1, footY: 3.0)
        legs.stroke()
    }

    private func drawLeg(path: NSBezierPath, hipX: CGFloat, hipY: CGFloat, footX: CGFloat, footY: CGFloat) {
        path.move(to: NSPoint(x: hipX, y: hipY))
        path.line(to: NSPoint(x: footX, y: footY))
    }

    private func drawSpark(frame: Int, phase: UsagePressurePhase) {
        guard phase != .calm else { return }
        let offset = CGFloat(frame % 3)
        NSColor.systemYellow.setFill()
        NSBezierPath(ovalIn: NSRect(x: 2 + offset, y: 13, width: 2, height: 2)).fill()
        NSBezierPath(ovalIn: NSRect(x: 4, y: 4 + offset, width: 1.8, height: 1.8)).fill()
    }

    private func drawPulse(frame: Int, phase: UsagePressurePhase, color: NSColor) {
        guard phase != .calm else { return }
        color.withAlphaComponent(0.28).setStroke()
        let inset = CGFloat(frame % 4) * 0.8
        let ring = NSBezierPath(ovalIn: NSRect(x: 2 + inset, y: 1 + inset, width: 18 - inset * 2, height: 16 - inset * 2))
        ring.lineWidth = 1
        ring.stroke()
    }
}
