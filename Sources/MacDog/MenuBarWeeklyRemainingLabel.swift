import AppKit
import CodexUsageCore
import Foundation

struct MenuBarWeeklyRemainingLabel: Equatable {
    let text: String?

    static let fontSize: CGFloat = 11
    static let trailingGap: CGFloat = 2
    static var font: NSFont {
        NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .regular)
    }

    static func make(
        state: UsageMonitorState,
        visible: Bool = true,
        now: Date = Date()
    ) -> MenuBarWeeklyRemainingLabel {
        guard visible, state.usageProviderMode != .claude else {
            return MenuBarWeeklyRemainingLabel(text: nil)
        }

        let remainingPercent: Double?
        switch state.runtimeProviderMode {
        case .codex:
            remainingPercent = state.codexLimit?.weekly?.remainingPercent
        case .grok:
            remainingPercent = state.grokUsage.cacheSnapshot?.freshWeekly(now: now)?.remainingPercent
        case .claude:
            remainingPercent = nil
        }

        guard let remainingPercent else {
            return MenuBarWeeklyRemainingLabel(text: nil)
        }

        let percent = Int(remainingPercent.rounded(.toNearestOrAwayFromZero))
        return MenuBarWeeklyRemainingLabel(text: "\(percent)%")
    }

    var attributedTitle: NSAttributedString? {
        guard let text else { return nil }
        return Self.makeAttributedTitle(visibleText: text)
    }

    var reservedWidth: CGFloat {
        attributedTitle?.size().width ?? 0
    }

    @MainActor
    func apply(to button: NSStatusBarButton) {
        button.imageHugsTitle = true
        button.font = Self.font
        if let attributedTitle {
            button.imagePosition = .imageTrailing
            button.attributedTitle = attributedTitle
        } else {
            button.attributedTitle = NSAttributedString()
            button.title = ""
            button.imagePosition = .imageOnly
        }
    }

    private static func makeAttributedTitle(visibleText: String) -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let digits = String(visibleText.dropLast())
        let padCount = max(0, 3 - digits.count)
        let padded = String(repeating: "\u{2007}", count: padCount) + visibleText
        let result = NSMutableAttributedString(string: padded, attributes: attributes)
        let templateWidth = NSAttributedString(string: "100%", attributes: attributes).size().width
        let paddedWidth = NSAttributedString(string: padded, attributes: attributes).size().width
        let leadingPad = max(0, templateWidth - paddedWidth)
        if leadingPad > 0.01 {
            result.insert(spacer(width: leadingPad), at: 0)
        }
        result.append(spacer(width: trailingGap))
        return result
    }

    private static func spacer(width: CGFloat) -> NSAttributedString {
        let image = NSImage(size: NSSize(width: max(width, 0.01), height: 1))
        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: image.size).fill()
        image.unlockFocus()
        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(x: 0, y: 0, width: width, height: 1)
        return NSAttributedString(attachment: attachment)
    }
}
