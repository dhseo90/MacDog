import AppKit

struct RunnerIconRenderer {
    static let frameCount = 8

    func image(
        frame: Int,
        phase: UsagePressurePhase,
        character: RunnerCharacter = .pup,
        reducedMotion: Bool = false
    ) -> NSImage {
        let renderedFrame = reducedMotion ? 0 : frame
        if let sprite = spriteImage(frame: renderedFrame, phase: phase, character: character) {
            return sprite
        }

        guard character == .pup else {
            return missingSpriteImage(character: character)
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
        drawPup(frameStride: stride, phase: phase, color: color)

        if phase == .limit {
            drawLimitWarning(size: size, lineWidth: 1.5)
        }

        image.unlockFocus()
        image.isTemplate = phase == .calm || phase == .active
        return image
    }

    func hasCompleteSpriteSet(for character: RunnerCharacter) -> Bool {
        (0..<Self.frameCount).allSatisfy { spriteURL(frame: $0, character: character) != nil }
    }

    private func spriteImage(frame: Int, phase: UsagePressurePhase, character: RunnerCharacter) -> NSImage? {
        guard let url = spriteURL(frame: frame, character: character) else { return nil }
        return spriteImage(from: url, phase: phase)
    }

    private func spriteURL(frame: Int, character: RunnerCharacter) -> URL? {
        let resourceName = "\(character.filePrefix)-\(frame % Self.frameCount)"
        let relativePath = "\(character.resourceSubdirectory)/\(resourceName).png"
        if let mainResourceURL = Bundle.main.resourceURL?.appendingPathComponent(relativePath),
           FileManager.default.fileExists(atPath: mainResourceURL.path) {
            return mainResourceURL
        }

        guard
            let url = Bundle.module.url(
                forResource: resourceName,
                withExtension: "png",
                subdirectory: character.resourceSubdirectory
        )
        else {
            return nil
        }

        return url
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

    private func missingSpriteImage(character: RunnerCharacter) -> NSImage {
        let image = NSImage(size: NSSize(width: 80, height: 48))
        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: image.size).fill()

        NSColor.systemGray.withAlphaComponent(0.55).setStroke()
        let outline = NSBezierPath(roundedRect: NSRect(x: 10, y: 10, width: 60, height: 28), xRadius: 6, yRadius: 6)
        outline.lineWidth = 3
        outline.stroke()

        NSColor.systemGray.withAlphaComponent(0.8).setFill()
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        (character.shortLabel as NSString).draw(
            in: NSRect(x: 10, y: 16, width: 60, height: 16),
            withAttributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .semibold),
                .foregroundColor: NSColor.systemGray,
                .paragraphStyle: paragraph
            ]
        )

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

    var shortLabel: String {
        switch self {
        case .pup:
            "PUP"
        case .bot:
            "BOT"
        }
    }

    var filePrefix: String {
        switch self {
        case .pup:
            "pup-runner"
        case .bot:
            "bot-runner"
        }
    }

    var resourceSubdirectory: String {
        switch self {
        case .pup:
            "Runner"
        case .bot:
            "Runner/Bot"
        }
    }
}
