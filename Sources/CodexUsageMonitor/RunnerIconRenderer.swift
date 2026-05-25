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
        let size = NSSize(width: 30, height: 18)
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
            warning.move(to: NSPoint(x: 27, y: 14))
            warning.line(to: NSPoint(x: 27, y: 7))
            warning.move(to: NSPoint(x: 27, y: 4))
            warning.line(to: NSPoint(x: 27, y: 3.8))
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
        let bounce = phase == .calm ? abs(run) * 0.25 : abs(run) * 0.75

        drawSpeedMarks(frameStride: frameStride, color: color)

        let tail = NSBezierPath()
        tail.lineWidth = 1.7
        tail.lineCapStyle = .round
        tail.move(to: NSPoint(x: 10.2, y: 10.4 + bounce))
        tail.curve(
            to: NSPoint(x: 6.1, y: 13.7 + run * 0.8),
            controlPoint1: NSPoint(x: 8.9, y: 12.1 + run * 0.5),
            controlPoint2: NSPoint(x: 7.4, y: 13.6 + run * 0.7)
        )
        tail.stroke()

        NSBezierPath(
            roundedRect: NSRect(x: 9.2, y: 7.0 + bounce, width: 11.9, height: 5.3),
            xRadius: 2.7,
            yRadius: 2.5
        ).fill()
        NSBezierPath(ovalIn: NSRect(x: 19.3, y: 8.9 + bounce, width: 5.6, height: 5.2)).fill()
        NSBezierPath(
            roundedRect: NSRect(x: 23.6, y: 9.7 + bounce, width: 3.6, height: 2.2),
            xRadius: 1.1,
            yRadius: 1.0
        ).fill()

        let ear = NSBezierPath()
        ear.move(to: NSPoint(x: 20.0, y: 12.8 + bounce))
        ear.line(to: NSPoint(x: 20.9 + paw * 0.2, y: 15.7 + bounce))
        ear.line(to: NSPoint(x: 22.2, y: 12.8 + bounce))
        ear.close()
        ear.fill()

        let legs = NSBezierPath()
        legs.lineWidth = 1.55
        legs.lineCapStyle = .round
        drawLeg(path: legs, hipX: 10.8, hipY: 7.1 + bounce, footX: 8.3 + paw * 1.2, footY: 3.0)
        drawLeg(path: legs, hipX: 13.6, hipY: 7.0 + bounce, footX: 14.8 - paw * 1.3, footY: 2.9)
        drawLeg(path: legs, hipX: 18.0, hipY: 7.2 + bounce, footX: 16.2 - paw * 1.2, footY: 3.0)
        drawLeg(path: legs, hipX: 20.0, hipY: 7.3 + bounce, footX: 22.5 + paw * 1.1, footY: 3.1)
        legs.stroke()
    }

    private func drawSpeedMarks(frameStride: CGFloat, color: NSColor) {
        let shift = CGFloat(Int(frameStride * 4)) * 0.2
        color.withAlphaComponent(0.75).setStroke()

        let marks = NSBezierPath()
        marks.lineWidth = 1.15
        marks.lineCapStyle = .round
        marks.move(to: NSPoint(x: 0.8 + shift, y: 12.4))
        marks.line(to: NSPoint(x: 6.4 + shift, y: 12.4))
        marks.move(to: NSPoint(x: 0.2 + shift, y: 9.0))
        marks.line(to: NSPoint(x: 7.4 + shift, y: 9.0))
        marks.move(to: NSPoint(x: 0.9 + shift, y: 5.6))
        marks.line(to: NSPoint(x: 6.1 + shift, y: 5.6))
        marks.stroke()

        color.setStroke()
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
