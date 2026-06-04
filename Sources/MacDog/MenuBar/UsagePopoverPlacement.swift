import AppKit

enum UsagePopoverPlacement {
    case menuBar
    case desktopPet

    var defaultPreferredEdge: NSRectEdge {
        switch self {
        case .menuBar:
            return .maxY
        case .desktopPet:
            return .maxX
        }
    }
}

enum UsagePopoverPlacementResolver {
    private static let screenPadding: CGFloat = 8
    private static let sourcePadding: CGFloat = 8

    static func anchorRect(sourceBounds: NSRect, placement: UsagePopoverPlacement) -> NSRect {
        guard placement == .menuBar else {
            return sourceBounds
        }

        let width = min(sourceBounds.width, 24)
        return NSRect(
            x: (sourceBounds.width - width) / 2,
            y: sourceBounds.minY,
            width: width,
            height: sourceBounds.height
        )
    }

    static func preferredEdge(
        sourceFrame: NSRect,
        screenFrame: NSRect,
        placement: UsagePopoverPlacement
    ) -> NSRectEdge {
        guard placement == .desktopPet else {
            return placement.defaultPreferredEdge
        }
        return shouldShowDesktopPopoverOnRight(sourceFrame: sourceFrame, screenFrame: screenFrame) ? .maxX : .minX
    }

    static func resolvedWindowFrame(
        currentPopoverFrame: NSRect,
        sourceFrame: NSRect,
        screenFrame: NSRect,
        placement: UsagePopoverPlacement
    ) -> NSRect {
        var frame = currentPopoverFrame
        switch placement {
        case .menuBar:
            frame.origin.x = sourceFrame.midX - frame.width / 2
            frame.origin.y = max(screenFrame.minY + screenPadding, sourceFrame.minY - frame.height - 4)
        case .desktopPet:
            let showOnRight = shouldShowDesktopPopoverOnRight(sourceFrame: sourceFrame, screenFrame: screenFrame)
            frame.origin.x = showOnRight
                ? sourceFrame.maxX + sourcePadding
                : sourceFrame.minX - frame.width - sourcePadding
            frame.origin.y = sourceFrame.midY - frame.height / 2
        }
        frame.origin.x = min(
            max(frame.origin.x, screenFrame.minX + screenPadding),
            screenFrame.maxX - frame.width - screenPadding
        )
        frame.origin.y = min(
            max(frame.origin.y, screenFrame.minY + screenPadding),
            screenFrame.maxY - frame.height - screenPadding
        )
        return frame
    }

    static func shouldShowDesktopPopoverOnRight(sourceFrame: NSRect, screenFrame: NSRect) -> Bool {
        sourceFrame.midX <= screenFrame.midX
    }
}
