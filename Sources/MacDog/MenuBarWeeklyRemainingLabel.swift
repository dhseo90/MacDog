import AppKit
import CodexUsageCore
import Foundation

struct MenuBarWeeklyRemainingLabel: Equatable {
    let text: String?

    static let fontSize: CGFloat = 9
    static let percentSignSize: CGFloat = 7
    static let trailingGap: CGFloat = 2
    static let outerInset: CGFloat = 1
    static let percentFieldHorizontalPadding: CGFloat = 4
    static let percentFieldVerticalPadding: CGFloat = 2
    static var font: NSFont {
        NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .medium)
    }
    static var percentSignFont: NSFont {
        NSFont.monospacedDigitSystemFont(ofSize: percentSignSize, weight: .medium)
    }
    static var textAttributes: [NSAttributedString.Key: Any] {
        [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]
    }

    static func make(
        state: UsageMonitorState,
        visible: Bool = true,
        showsPercentSign: Bool = true,
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
        return MenuBarWeeklyRemainingLabel(text: showsPercentSign ? "\(percent)%" : "\(percent)")
    }

    var attributedTitle: NSAttributedString? {
        guard let text else { return nil }
        return Self.attributedPercent(text)
    }

    static func attributedPercent(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let digitAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]
        if text.hasSuffix("%") {
            result.append(NSAttributedString(string: String(text.dropLast()), attributes: digitAttributes))
            result.append(
                NSAttributedString(
                    string: "%",
                    attributes: [
                        .font: percentSignFont,
                        .foregroundColor: NSColor.labelColor,
                        .baselineOffset: 1
                    ]
                )
            )
        } else {
            result.append(NSAttributedString(string: text, attributes: digitAttributes))
        }
        return result
    }

    static func compactLength(titleWidth: CGFloat, imageWidth: CGFloat) -> CGFloat {
        let textAndGap = titleWidth > 0 ? titleWidth + trailingGap : 0
        return ceil(textAndGap + imageWidth + outerInset * 2)
    }

    static func placement(
        percentText: String?,
        imageSize: NSSize,
        height: CGFloat
    ) -> (percent: NSRect?, image: NSRect, width: CGFloat) {
        var x = outerInset
        var percentFrame: NSRect?
        if let percentText {
            let textSize = attributedPercent(percentText).size()
            let width = ceil(textSize.width) + percentFieldHorizontalPadding
            let textHeight = ceil(textSize.height) + percentFieldVerticalPadding
            percentFrame = NSRect(
                x: x,
                y: ((height - textHeight) / 2).rounded(.toNearestOrAwayFromZero),
                width: width,
                height: textHeight
            )
            x += width + trailingGap
        }
        let imageFrame = NSRect(
            x: x,
            y: ((height - imageSize.height) / 2).rounded(.toNearestOrAwayFromZero),
            width: imageSize.width,
            height: imageSize.height
        )
        return (percentFrame, imageFrame, ceil(imageFrame.maxX + outerInset))
    }
}
