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

        let size = character == .bot ? NSSize(width: 80, height: 48) : NSSize(width: 30, height: 18)
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
            drawLimitWarning(size: size, lineWidth: character == .bot ? 4 : 1.5)
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
            drawLimitWarning(size: base.size, lineWidth: 4)
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
        let bounce = phase == .calm ? abs(run) * 0.28 : abs(run) * 1.1

        drawBotSpeedMarks(frameStride: frameStride, color: color)

        let bodyY = 16.2 + bounce
        let headY = 25.7 + bounce

        color.setStroke()
        color.setFill()

        let rearModule = NSBezierPath(roundedRect: NSRect(x: 25.8, y: bodyY + 4.8, width: 6.2, height: 8.4), xRadius: 2.1, yRadius: 2.1)
        rearModule.fill()

        let tail = NSBezierPath()
        tail.lineWidth = 3.1
        tail.lineCapStyle = .round
        tail.move(to: NSPoint(x: 27.0, y: bodyY + 10.8))
        tail.curve(
            to: NSPoint(x: 20.2, y: bodyY + 14.0 + run * 0.7),
            controlPoint1: NSPoint(x: 24.6, y: bodyY + 12.8),
            controlPoint2: NSPoint(x: 22.3, y: bodyY + 13.8 + run * 0.4)
        )
        tail.stroke()

        let body = NSBezierPath(roundedRect: NSRect(x: 30.0, y: bodyY, width: 29.2, height: 15.2), xRadius: 5.1, yRadius: 5.1)
        body.fill()

        let chest = NSBezierPath(roundedRect: NSRect(x: 53.2, y: bodyY + 2.1, width: 8.0, height: 11.2), xRadius: 3.2, yRadius: 3.2)
        chest.fill()

        let neck = NSBezierPath(roundedRect: NSRect(x: 55.0, y: bodyY + 10.8, width: 5.8, height: 6.6), xRadius: 1.8, yRadius: 1.8)
        neck.fill()

        let head = NSBezierPath(roundedRect: NSRect(x: 58.6, y: headY, width: 14.8, height: 11.6), xRadius: 3.2, yRadius: 3.2)
        head.fill()

        let snout = NSBezierPath(roundedRect: NSRect(x: 70.4, y: headY + 3.2, width: 5.8, height: 5.0), xRadius: 1.7, yRadius: 1.7)
        snout.fill()

        let antenna = NSBezierPath()
        antenna.lineWidth = 2.7
        antenna.lineCapStyle = .round
        antenna.move(to: NSPoint(x: 64.2, y: headY + 10.4))
        antenna.line(to: NSPoint(x: 65.6 + run * 0.9, y: headY + 15.0))
        antenna.stroke()

        NSBezierPath(ovalIn: NSRect(x: 63.7 + run * 0.9, y: headY + 13.8, width: 4.2, height: 4.2)).fill()

        let legs = NSBezierPath()
        legs.lineWidth = 3.2
        legs.lineCapStyle = .round
        drawBotLeg(
            path: legs,
            hip: NSPoint(x: 34.4, y: bodyY + 1.9),
            knee: NSPoint(x: 30.5 - paw * 3.1, y: 11.3),
            foot: NSPoint(x: 25.7 - paw * 4.2, y: 7.0)
        )
        drawBotLeg(
            path: legs,
            hip: NSPoint(x: 40.2, y: bodyY + 1.5),
            knee: NSPoint(x: 42.3 + paw * 2.6, y: 11.2),
            foot: NSPoint(x: 47.8 + paw * 3.7, y: 7.0)
        )
        drawBotLeg(
            path: legs,
            hip: NSPoint(x: 52.0, y: bodyY + 1.9),
            knee: NSPoint(x: 50.4 + paw * 2.9, y: 11.2),
            foot: NSPoint(x: 46.2 + paw * 4.0, y: 7.0)
        )
        drawBotLeg(
            path: legs,
            hip: NSPoint(x: 57.0, y: bodyY + 2.0),
            knee: NSPoint(x: 61.4 - paw * 2.8, y: 11.2),
            foot: NSPoint(x: 67.5 - paw * 3.8, y: 7.0)
        )
        legs.stroke()

        NSBezierPath(roundedRect: NSRect(x: 22.6 - paw * 4.2, y: 5.1, width: 7.2, height: 3.1), xRadius: 1.4, yRadius: 1.4).fill()
        NSBezierPath(roundedRect: NSRect(x: 44.3 + paw * 3.7, y: 5.1, width: 7.2, height: 3.1), xRadius: 1.4, yRadius: 1.4).fill()
        NSBezierPath(roundedRect: NSRect(x: 42.8 + paw * 4.0, y: 5.1, width: 7.2, height: 3.1), xRadius: 1.4, yRadius: 1.4).fill()
        NSBezierPath(roundedRect: NSRect(x: 64.0 - paw * 3.8, y: 5.1, width: 7.2, height: 3.1), xRadius: 1.4, yRadius: 1.4).fill()

        NSColor.black.withAlphaComponent(0.72).setFill()
        NSBezierPath(ovalIn: NSRect(x: 64.4, y: headY + 6.8, width: 3.1, height: 3.1)).fill()

        NSColor.black.withAlphaComponent(0.45).setFill()
        NSBezierPath(roundedRect: NSRect(x: 37.4, y: bodyY + 7.2, width: 11.8, height: 2.8), xRadius: 1.2, yRadius: 1.2).fill()
        NSBezierPath(roundedRect: NSRect(x: 66.4, y: headY + 3.7, width: 5.9, height: 1.9), xRadius: 0.9, yRadius: 0.9).fill()
    }

    private func drawBotLeg(path: NSBezierPath, hip: NSPoint, knee: NSPoint, foot: NSPoint) {
        path.move(to: hip)
        path.curve(
            to: foot,
            controlPoint1: NSPoint(x: knee.x, y: knee.y + 1.0),
            controlPoint2: knee
        )
    }

    private func drawBotSpeedMarks(frameStride: CGFloat, color: NSColor) {
        let shift = CGFloat(Int(frameStride * 4)) * 0.8
        color.withAlphaComponent(0.75).setStroke()

        let marks = NSBezierPath()
        marks.lineWidth = 2.5
        marks.lineCapStyle = .round
        marks.move(to: NSPoint(x: 5.6 + shift, y: 31.6))
        marks.line(to: NSPoint(x: 20.5 + shift, y: 31.6))
        marks.move(to: NSPoint(x: 2.8 + shift, y: 24.0))
        marks.line(to: NSPoint(x: 21.8 + shift, y: 24.0))
        marks.move(to: NSPoint(x: 5.7 + shift, y: 16.5))
        marks.line(to: NSPoint(x: 20.0 + shift, y: 16.5))
        marks.stroke()

        color.setStroke()
    }

    private func drawLimitWarning(size: NSSize, lineWidth: CGFloat) {
        NSColor.systemRed.setStroke()
        let warning = NSBezierPath()
        warning.lineWidth = lineWidth
        warning.lineCapStyle = .round
        let x = size.width - lineWidth - 3
        warning.move(to: NSPoint(x: x, y: size.height - 8))
        warning.line(to: NSPoint(x: x, y: size.height - 22))
        warning.move(to: NSPoint(x: x, y: size.height - 31))
        warning.line(to: NSPoint(x: x, y: size.height - 31.2))
        warning.stroke()
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
