import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
enum CodexUsageGraphImageExporter {
    static let defaultImageSize = CGSize(width: 520, height: 180)

    static func pngData<V: View>(
        for view: V,
        size: CGSize = defaultImageSize,
        scale: CGFloat = 2
    ) -> Data? {
        let rootView = view
            .frame(width: size.width, height: size.height)
            .background(Color(nsColor: .windowBackgroundColor))
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.appearance = NSAppearance(named: .darkAqua)
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.setFrameSize(size)
        hostingView.layoutSubtreeIfNeeded()

        let pixelWidth = max(1, Int(size.width * scale))
        let pixelHeight = max(1, Int(size.height * scale))
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelWidth,
            pixelsHigh: pixelHeight,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }
        bitmap.size = size
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        return bitmap.representation(using: .png, properties: [:])
    }

    @discardableResult
    static func copyPNGData(
        _ data: Data,
        to pasteboard: NSPasteboard = .general
    ) -> Bool {
        pasteboard.declareTypes([.png], owner: nil)
        return pasteboard.setData(data, forType: .png)
    }

    static func writePNGData(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: [.atomic])
    }

    static func exportPNGData(
        _ data: Data,
        suggestedFileName: String = "macdog-codex-usage-graph.png"
    ) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedFileName
        panel.begin { response in
            guard response == .OK,
                  let url = panel.url
            else {
                return
            }
            try? writePNGData(data, to: url)
        }
    }
}
