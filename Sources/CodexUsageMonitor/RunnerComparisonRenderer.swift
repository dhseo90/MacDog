import AppKit
import Foundation

enum RunnerComparisonCommand {
    static func runIfRequested(arguments: [String]) -> Bool {
        guard arguments.dropFirst().first == "--render-runner-comparison" else {
            return false
        }

        let outputPath = arguments.dropFirst(2).first ?? "Docs/RunnerComparison/pup-vs-bot.png"
        do {
            try RunnerComparisonRenderer().render(to: URL(fileURLWithPath: outputPath))
            print("Rendered runner comparison: \(outputPath)")
            return true
        } catch {
            fputs("runner comparison render failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
}

struct RunnerComparisonRenderer {
    private let renderer = RunnerIconRenderer()
    private let phases: [(UsagePressurePhase, String)] = [
        (.calm, "Calm"),
        (.active, "Active"),
        (.fast, "Fast"),
        (.sprint, "Sprint"),
        (.limit, "Limit")
    ]
    private let sizes: [CGFloat] = [16, 18, 22]
    private let characters: [RunnerCharacter] = [.pup, .bot]

    func render(to outputURL: URL) throws {
        let image = makeImage()
        guard let data = image.pngData() else {
            throw RunnerComparisonError.pngEncodingFailed
        }

        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: outputURL, options: [.atomic])
    }

    private func makeImage() -> NSImage {
        let labelWidth: CGFloat = 120
        let cellWidth: CGFloat = 118
        let headerHeight: CGFloat = 42
        let rowHeight: CGFloat = 44
        let footerHeight: CGFloat = 18
        let width = labelWidth + CGFloat(phases.count) * cellWidth
        let height = headerHeight + CGFloat(characters.count * sizes.count) * rowHeight + footerHeight

        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        NSColor.windowBackgroundColor.setFill()
        NSRect(origin: .zero, size: image.size).fill()

        drawHeaders(labelWidth: labelWidth, cellWidth: cellWidth, height: height)
        drawRows(labelWidth: labelWidth, cellWidth: cellWidth, headerHeight: headerHeight, rowHeight: rowHeight, height: height)

        image.unlockFocus()
        return image
    }

    private func drawHeaders(labelWidth: CGFloat, cellWidth: CGFloat, height: CGFloat) {
        drawText(
            "Runner",
            in: NSRect(x: 16, y: height - 30, width: labelWidth - 20, height: 18),
            font: .systemFont(ofSize: 12, weight: .semibold),
            color: .secondaryLabelColor
        )

        for (index, phase) in phases.enumerated() {
            let rect = NSRect(
                x: labelWidth + CGFloat(index) * cellWidth,
                y: height - 30,
                width: cellWidth,
                height: 18
            )
            drawText(phase.1, in: rect, font: .systemFont(ofSize: 12, weight: .semibold), color: .secondaryLabelColor, alignment: .center)
        }
    }

    private func drawRows(
        labelWidth: CGFloat,
        cellWidth: CGFloat,
        headerHeight: CGFloat,
        rowHeight: CGFloat,
        height: CGFloat
    ) {
        var row = 0

        for character in characters {
            for size in sizes {
                let y = height - headerHeight - CGFloat(row + 1) * rowHeight
                drawText(
                    "\(character.label) \(Int(size))pt",
                    in: NSRect(x: 16, y: y + 13, width: labelWidth - 20, height: 18),
                    font: .systemFont(ofSize: 12),
                    color: .labelColor
                )

                for (phaseIndex, phase) in phases.enumerated() {
                    let cellX = labelWidth + CGFloat(phaseIndex) * cellWidth
                    let menuRect = NSRect(x: cellX + 17, y: y + 10, width: cellWidth - 34, height: 24)
                    NSColor.separatorColor.withAlphaComponent(0.35).setStroke()
                    NSBezierPath(roundedRect: menuRect, xRadius: 4, yRadius: 4).stroke()

                    let icon = renderer.image(frame: phaseIndex, phase: phase.0, character: character)
                    let scale = size / max(icon.size.height, 1)
                    let drawSize = NSSize(width: icon.size.width * scale, height: size)
                    let drawRect = NSRect(
                        x: menuRect.midX - drawSize.width / 2,
                        y: menuRect.midY - drawSize.height / 2,
                        width: drawSize.width,
                        height: drawSize.height
                    )
                    icon.draw(in: drawRect)
                }

                row += 1
            }
        }
    }

    private func drawText(
        _ text: String,
        in rect: NSRect,
        font: NSFont,
        color: NSColor,
        alignment: NSTextAlignment = .left
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        (text as NSString).draw(
            in: rect,
            withAttributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        )
    }
}

private enum RunnerComparisonError: LocalizedError {
    case pngEncodingFailed

    var errorDescription: String? {
        switch self {
        case .pngEncodingFailed:
            "Unable to encode runner comparison as PNG."
        }
    }
}

private extension NSImage {
    func pngData() -> Data? {
        guard
            let tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffRepresentation)
        else { return nil }

        return bitmap.representation(using: .png, properties: [:])
    }
}
