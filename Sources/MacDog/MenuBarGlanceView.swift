import AppKit

@MainActor
final class MenuBarGlanceView: NSView {
    private let imageView = NSImageView()
    private let percentField = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        imageView.imageScaling = .scaleNone
        imageView.imageAlignment = .alignCenter
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = NSColor.clear.cgColor
        percentField.isBezeled = false
        percentField.isBordered = false
        percentField.drawsBackground = false
        percentField.isEditable = false
        percentField.isSelectable = false
        percentField.refusesFirstResponder = true
        percentField.alignment = .left
        percentField.cell?.lineBreakMode = .byClipping
        addSubview(imageView)
        addSubview(percentField)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(percentText: String?, image: NSImage?) {
        imageView.image = image
        if let percentText {
            percentField.attributedStringValue = MenuBarWeeklyRemainingLabel.attributedPercent(percentText)
            percentField.isHidden = false
        } else {
            percentField.attributedStringValue = NSAttributedString()
            percentField.isHidden = true
        }
        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    override var intrinsicContentSize: NSSize {
        let height = max(MenuBarIconRenderer.imageSize.height, 22)
        let placement = MenuBarWeeklyRemainingLabel.placement(
            percentText: percentField.isHidden ? nil : percentField.stringValue,
            imageSize: imageView.image?.size ?? .zero,
            height: height
        )
        return NSSize(width: placement.width, height: height)
    }

    override func layout() {
        super.layout()
        let placement = MenuBarWeeklyRemainingLabel.placement(
            percentText: percentField.isHidden ? nil : percentField.stringValue,
            imageSize: imageView.image?.size ?? .zero,
            height: bounds.height
        )
        percentField.frame = placement.percent ?? .zero
        imageView.frame = placement.image
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
