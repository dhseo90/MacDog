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
        let size = NSSize(width: 32, height: 18)
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
        image.isTemplate = false
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
        let tailLift = run * 1.4

        let tail = NSBezierPath()
        tail.lineWidth = 1.8
        tail.lineCapStyle = .round
        tail.move(to: NSPoint(x: 7.0, y: 10.6 + bounce))
        tail.curve(
            to: NSPoint(x: 2.1, y: 13.8 + tailLift),
            controlPoint1: NSPoint(x: 5.2, y: 12.2 + tailLift),
            controlPoint2: NSPoint(x: 3.5, y: 14.0 + tailLift)
        )
        tail.stroke()

        NSBezierPath(roundedRect: NSRect(x: 5.8, y: 7.0 + bounce, width: 15.2, height: 5.4), xRadius: 2.8, yRadius: 2.6).fill()
        NSBezierPath(ovalIn: NSRect(x: 19.7, y: 9.0 + bounce, width: 5.9, height: 5.1)).fill()
        NSBezierPath(roundedRect: NSRect(x: 24.1, y: 9.5 + bounce, width: 4.3, height: 2.4), xRadius: 1.2, yRadius: 1.1).fill()

        let ear = NSBezierPath()
        ear.move(to: NSPoint(x: 20.3, y: 13.0 + bounce))
        ear.line(to: NSPoint(x: 21.3 + paw * 0.25, y: 16.1 + bounce))
        ear.line(to: NSPoint(x: 22.7, y: 13.0 + bounce))
        ear.close()
        ear.fill()

        NSColor.systemBlue.setStroke()
        let collar = NSBezierPath()
        collar.lineWidth = 1.2
        collar.lineCapStyle = .round
        collar.move(to: NSPoint(x: 19.7, y: 8.8 + bounce))
        collar.line(to: NSPoint(x: 20.2, y: 12.9 + bounce))
        collar.stroke()

        color.setStroke()
        color.setFill()

        let legs = NSBezierPath()
        legs.lineWidth = 1.7
        legs.lineCapStyle = .round
        drawLeg(path: legs, hipX: 8.1, hipY: 7.0 + bounce, footX: 5.4 + paw * 1.7, footY: 2.9)
        drawLeg(path: legs, hipX: 11.6, hipY: 6.9 + bounce, footX: 13.2 - paw * 1.8, footY: 2.8)
        drawLeg(path: legs, hipX: 17.1, hipY: 7.1 + bounce, footX: 15.2 - paw * 1.6, footY: 2.9)
        drawLeg(path: legs, hipX: 19.2, hipY: 7.2 + bounce, footX: 21.8 + paw * 1.5, footY: 3.2)
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
