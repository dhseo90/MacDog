import AppKit
import SwiftUI

struct RunnerIconRenderer {
    static let frameCount = 8

    func image(
        frame: Int,
        phase: UsagePressurePhase,
        character: RunnerCharacter = .pup,
        reducedMotion: Bool = false
    ) -> NSImage {
        let renderedFrame = reducedMotion ? 0 : frame
        if character == .pup, let sprite = spriteImage(frame: renderedFrame, phase: phase) {
            return sprite
        }

        let size = NSSize(width: 30, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        let color = color(for: phase)
        color.setStroke()
        color.setFill()

        let stride = CGFloat(renderedFrame % Self.frameCount) / CGFloat(Self.frameCount)
        switch character {
        case .pup:
            drawPup(frameStride: stride, phase: phase, color: color)
        case .bot:
            drawBot(frameStride: stride, phase: phase, color: color)
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
        image.isTemplate = character == .pup && (phase == .calm || phase == .active)
        return image
    }

    private func spriteImage(frame: Int, phase: UsagePressurePhase) -> NSImage? {
        let resourceName = "pup-runner-\(frame % Self.frameCount)"
        if let mainResourceURL = Bundle.main.resourceURL?
            .appendingPathComponent("Runner", isDirectory: true)
            .appendingPathComponent("\(resourceName).png"),
            let image = spriteImage(from: mainResourceURL, phase: phase) {
            return image
        }

        guard
            let url = Bundle.module.url(
                forResource: resourceName,
                withExtension: "png",
                subdirectory: "Runner"
        )
        else { return nil }

        return spriteImage(from: url, phase: phase)
    }

    private func spriteImage(from url: URL, phase: UsagePressurePhase) -> NSImage? {
        guard let base = NSImage(contentsOf: url) else { return nil }
        let image = NSImage(size: base.size)
        image.lockFocus()
        base.draw(in: NSRect(origin: .zero, size: base.size))

        if phase == .limit {
            NSColor.systemRed.setStroke()
            let warning = NSBezierPath()
            warning.lineWidth = 4
            warning.lineCapStyle = .round
            warning.move(to: NSPoint(x: base.size.width - 7, y: base.size.height - 8))
            warning.line(to: NSPoint(x: base.size.width - 7, y: base.size.height - 22))
            warning.move(to: NSPoint(x: base.size.width - 7, y: base.size.height - 31))
            warning.line(to: NSPoint(x: base.size.width - 7, y: base.size.height - 31.2))
            warning.stroke()
        }

        image.unlockFocus()
        image.isTemplate = false
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

    private func drawPup(frameStride: CGFloat, phase: UsagePressurePhase, color: NSColor) {
        let run = sin(frameStride * .pi * 2)
        let paw = cos(frameStride * .pi * 2)
        let bounce = phase == .calm ? abs(run) * 0.18 : abs(run) * 0.65

        drawSpeedMarks(frameStride: frameStride, color: color)

        let bodyY = 7.0 + bounce
        let headY = 9.1 + bounce

        let tail = NSBezierPath()
        tail.lineWidth = 1.45
        tail.lineCapStyle = .round
        tail.move(to: NSPoint(x: 10.1, y: 10.9 + bounce))
        tail.curve(
            to: NSPoint(x: 6.1, y: 13.6 + run * 0.55),
            controlPoint1: NSPoint(x: 8.8, y: 12.4 + run * 0.25),
            controlPoint2: NSPoint(x: 7.3, y: 13.5 + run * 0.45)
        )
        tail.stroke()

        let body = NSBezierPath()
        body.move(to: NSPoint(x: 10.0, y: bodyY + 2.7))
        body.curve(
            to: NSPoint(x: 20.8, y: bodyY + 3.0),
            controlPoint1: NSPoint(x: 12.4, y: bodyY + 5.6),
            controlPoint2: NSPoint(x: 18.0, y: bodyY + 5.4)
        )
        body.curve(
            to: NSPoint(x: 19.2, y: bodyY + 0.4),
            controlPoint1: NSPoint(x: 21.3, y: bodyY + 1.6),
            controlPoint2: NSPoint(x: 20.3, y: bodyY + 0.7)
        )
        body.curve(
            to: NSPoint(x: 10.2, y: bodyY + 0.5),
            controlPoint1: NSPoint(x: 16.5, y: bodyY - 0.6),
            controlPoint2: NSPoint(x: 12.5, y: bodyY - 0.5)
        )
        body.curve(
            to: NSPoint(x: 10.0, y: bodyY + 2.7),
            controlPoint1: NSPoint(x: 8.8, y: bodyY + 1.2),
            controlPoint2: NSPoint(x: 8.9, y: bodyY + 2.2)
        )
        body.close()
        body.fill()

        let chest = NSBezierPath(ovalIn: NSRect(x: 17.7, y: bodyY + 1.0, width: 3.5, height: 4.1))
        chest.fill()

        let head = NSBezierPath(ovalIn: NSRect(x: 20.2, y: headY, width: 5.1, height: 4.8))
        head.fill()

        let snout = NSBezierPath()
        snout.move(to: NSPoint(x: 24.0, y: headY + 2.9))
        snout.curve(
            to: NSPoint(x: 27.2, y: headY + 1.8),
            controlPoint1: NSPoint(x: 25.6, y: headY + 2.9),
            controlPoint2: NSPoint(x: 26.8, y: headY + 2.7)
        )
        snout.curve(
            to: NSPoint(x: 24.2, y: headY + 0.8),
            controlPoint1: NSPoint(x: 26.4, y: headY + 0.8),
            controlPoint2: NSPoint(x: 25.5, y: headY + 0.6)
        )
        snout.close()
        snout.fill()

        let ear = NSBezierPath()
        ear.move(to: NSPoint(x: 20.8, y: headY + 3.5))
        ear.curve(
            to: NSPoint(x: 22.7 + paw * 0.12, y: headY + 5.8),
            controlPoint1: NSPoint(x: 20.9, y: headY + 4.7),
            controlPoint2: NSPoint(x: 21.7, y: headY + 5.6)
        )
        ear.curve(
            to: NSPoint(x: 23.2, y: headY + 2.8),
            controlPoint1: NSPoint(x: 23.6, y: headY + 5.2),
            controlPoint2: NSPoint(x: 24.0, y: headY + 3.7)
        )
        ear.close()
        ear.fill()

        NSColor.black.withAlphaComponent(0.65).setFill()
        NSBezierPath(ovalIn: NSRect(x: 23.7, y: headY + 2.5, width: 0.8, height: 0.8)).fill()

        color.setStroke()
        color.setFill()

        let legs = NSBezierPath()
        legs.lineWidth = 1.45
        legs.lineCapStyle = .round
        drawBentLeg(
            path: legs,
            hip: NSPoint(x: 11.2, y: bodyY + 0.8),
            knee: NSPoint(x: 9.3 - paw * 0.9, y: 5.0),
            foot: NSPoint(x: 7.0 - paw * 1.6, y: 3.0)
        )
        drawBentLeg(
            path: legs,
            hip: NSPoint(x: 14.2, y: bodyY + 0.6),
            knee: NSPoint(x: 15.4 + paw * 0.9, y: 5.0),
            foot: NSPoint(x: 17.4 + paw * 1.5, y: 2.9)
        )
        drawBentLeg(
            path: legs,
            hip: NSPoint(x: 18.2, y: bodyY + 0.8),
            knee: NSPoint(x: 17.1 + paw * 1.0, y: 5.0),
            foot: NSPoint(x: 15.3 + paw * 1.4, y: 3.0)
        )
        drawBentLeg(
            path: legs,
            hip: NSPoint(x: 20.1, y: bodyY + 0.9),
            knee: NSPoint(x: 22.0 - paw * 0.8, y: 5.0),
            foot: NSPoint(x: 24.8 - paw * 1.2, y: 3.1)
        )
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

    private func drawBentLeg(path: NSBezierPath, hip: NSPoint, knee: NSPoint, foot: NSPoint) {
        path.move(to: hip)
        path.curve(
            to: foot,
            controlPoint1: NSPoint(x: knee.x, y: knee.y + 0.7),
            controlPoint2: knee
        )
    }

    private func drawBot(frameStride: CGFloat, phase: UsagePressurePhase, color: NSColor) {
        let run = sin(frameStride * .pi * 2)
        let paw = cos(frameStride * .pi * 2)
        let bounce = phase == .calm ? abs(run) * 0.12 : abs(run) * 0.5

        drawSpeedMarks(frameStride: frameStride, color: color)

        let bodyY = 5.2 + bounce
        let headY = 9.0 + bounce

        color.setStroke()
        color.setFill()

        let antenna = NSBezierPath()
        antenna.lineWidth = 1.25
        antenna.lineCapStyle = .round
        antenna.move(to: NSPoint(x: 18.4, y: headY + 6.3))
        antenna.line(to: NSPoint(x: 19.3 + run * 0.35, y: headY + 8.1))
        antenna.stroke()

        NSBezierPath(ovalIn: NSRect(x: 18.6 + run * 0.35, y: headY + 7.7, width: 1.5, height: 1.5)).fill()

        let head = NSBezierPath(roundedRect: NSRect(x: 13.2, y: headY, width: 11.1, height: 6.4), xRadius: 1.6, yRadius: 1.6)
        head.fill()

        let body = NSBezierPath(roundedRect: NSRect(x: 11.6, y: bodyY, width: 13.0, height: 5.6), xRadius: 1.6, yRadius: 1.6)
        body.fill()

        let armPath = NSBezierPath()
        armPath.lineWidth = 1.35
        armPath.lineCapStyle = .round
        armPath.move(to: NSPoint(x: 12.0, y: bodyY + 3.6))
        armPath.line(to: NSPoint(x: 8.8 - paw * 0.6, y: bodyY + 2.4))
        armPath.move(to: NSPoint(x: 24.0, y: bodyY + 3.6))
        armPath.line(to: NSPoint(x: 26.8 + paw * 0.6, y: bodyY + 2.4))
        armPath.stroke()

        let legs = NSBezierPath()
        legs.lineWidth = 1.45
        legs.lineCapStyle = .round
        legs.move(to: NSPoint(x: 15.2, y: bodyY + 0.4))
        legs.line(to: NSPoint(x: 13.2 - paw * 1.1, y: 2.7))
        legs.move(to: NSPoint(x: 21.0, y: bodyY + 0.4))
        legs.line(to: NSPoint(x: 23.0 + paw * 1.1, y: 2.7))
        legs.stroke()

        botAccentColor(for: phase).setFill()
        NSBezierPath(ovalIn: NSRect(x: 16.0, y: headY + 3.4, width: 1.7, height: 1.7)).fill()
        NSBezierPath(ovalIn: NSRect(x: 20.1, y: headY + 3.4, width: 1.7, height: 1.7)).fill()

        NSColor.black.withAlphaComponent(0.45).setFill()
        NSBezierPath(roundedRect: NSRect(x: 15.4, y: bodyY + 2.2, width: 5.7, height: 1.1), xRadius: 0.5, yRadius: 0.5).fill()
    }

    private func botAccentColor(for phase: UsagePressurePhase) -> NSColor {
        switch phase {
        case .calm:
            .black.withAlphaComponent(0.65)
        case .active:
            .controlAccentColor
        case .fast:
            .systemOrange
        case .sprint, .limit:
            .systemRed
        }
    }
}

enum RunnerCharacter: String, CaseIterable, Identifiable {
    case pup
    case bot

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pup:
            "Codex Pup"
        case .bot:
            "Codex Bot"
        }
    }
}
