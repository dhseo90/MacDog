import AppKit

@MainActor
final class FloatingPetController: NSObject {
    private let spriteSet = DesktopPetSpriteSet()
    private let petView: FloatingPetView
    private let actionHandler: (PetAction) -> Void
    private let menuProvider: (PetSurface) -> NSMenu
    private var panel: NSPanel?
    private var updateTimer: Timer?
    private var frameIndex = 0
    private var frameElapsed: TimeInterval = 0
    private var retargetElapsed: TimeInterval = 0
    private var nextRetargetInterval: TimeInterval = 3.8
    private var heading: CGFloat = 0
    private var targetHeading: CGFloat = 0
    private var speed: CGFloat = 54
    private var targetSpeed: CGFloat = 54
    private var lastUpdateTimestamp: TimeInterval?
    private var isDragging = false
    private var state = UsageMonitorState.empty

    private static let petSize = NSSize(width: 96, height: 102)
    private static let tickInterval: TimeInterval = 1.0 / 30.0
    private static let maxMovementStep: TimeInterval = 1.0 / 20.0
    private static let speedResponse = 4.0
    private static let maxTurnRadiansPerSecond = CGFloat.pi * 0.85
    private static let retargetRange: ClosedRange<TimeInterval> = 2.8...4.8

    init(
        actionHandler: @escaping (PetAction) -> Void,
        menuProvider: @escaping (PetSurface) -> NSMenu
    ) {
        self.actionHandler = actionHandler
        self.menuProvider = menuProvider
        self.petView = FloatingPetView(frame: NSRect(origin: .zero, size: FloatingPetController.petSize))
        super.init()
        petView.onClick = { [weak self] in self?.actionHandler(.showUsageDetails) }
        petView.onRightClick = { [weak self] point in self?.showMenu(at: point) }
        petView.onDragStarted = { [weak self] in self?.isDragging = true }
        petView.onDragMoved = { [weak self] delta, startFrame in self?.moveDrag(delta: delta, from: startFrame) }
        petView.onDragEnded = { [weak self] in self?.finishDrag() }
    }

    var isShown: Bool {
        panel?.isVisible == true
    }

    func show() {
        if isShown {
            renderFrame()
            return
        }

        let panel = panel ?? makePanel()
        self.panel = panel
        restorePositionIfNeeded()
        panel.orderFrontRegardless()
        retargetMotionForCurrentState()
        restartUpdateTimer()
        renderFrame()
    }

    func hide() {
        saveCurrentPosition()
        stopUpdateTimer()
        panel?.orderOut(nil)
    }

    func update(state: UsageMonitorState) {
        let previousState = self.state
        self.state = state
        if isShown {
            if state.phase == .limit {
                speed = 0
                targetSpeed = 0
            }
            if previousState.phase != state.phase {
                retargetMotionForCurrentState()
            }
            if previousState.reducedMotion != state.reducedMotion ||
                previousState.animationPaused != state.animationPaused ||
                previousState.phase != state.phase {
                restartUpdateTimer()
            }
            renderFrame()
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: defaultOrigin(), size: Self.petSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = false
        panel.contentView = petView
        return panel
    }

    private func restartUpdateTimer() {
        stopUpdateTimer()
        lastUpdateTimestamp = nil
        frameElapsed = 0
        retargetElapsed = 0
        nextRetargetInterval = Self.randomRetargetInterval()

        guard !state.animationPaused else { return }

        let interval = updateTimerInterval()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateOneTick()
            }
        }
        timer.tolerance = min(interval * 0.25, 0.08)
        RunLoop.main.add(timer, forMode: .common)
        updateTimer = timer
    }

    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
        lastUpdateTimestamp = nil
    }

    private func updateTimerInterval() -> TimeInterval {
        canMove ? Self.tickInterval : desktopFrameInterval()
    }

    private var canMove: Bool {
        !state.reducedMotion && !state.animationPaused && state.phase != .limit
    }

    private func updateOneTick() {
        guard isShown else { return }

        let elapsed = updateElapsedTime()
        var needsRender = advanceAnimationFrames(elapsed: elapsed)

        if canMove {
            retargetElapsed += elapsed
            if retargetElapsed >= nextRetargetInterval {
                retargetElapsed = 0
                nextRetargetInterval = Self.randomRetargetInterval()
                chooseNextMotionTarget()
            }

            needsRender = moveOneTick(elapsed: min(elapsed, Self.maxMovementStep)) || needsRender
        }

        if needsRender {
            renderFrame()
        }
    }

    private func updateElapsedTime() -> TimeInterval {
        let now = ProcessInfo.processInfo.systemUptime
        defer { lastUpdateTimestamp = now }

        guard let lastUpdateTimestamp else {
            return updateTimerInterval()
        }

        return max(0, now - lastUpdateTimestamp)
    }

    private func advanceAnimationFrames(elapsed: TimeInterval) -> Bool {
        let interval = desktopFrameInterval()
        frameElapsed += elapsed
        guard frameElapsed >= interval else { return false }

        let steps = min(max(Int(frameElapsed / interval), 1), 4)
        frameIndex += steps
        frameElapsed = frameElapsed.truncatingRemainder(dividingBy: interval)
        return true
    }

    private func renderFrame() {
        let pose = currentPose()
        let frame = spriteSet.frame(pose: pose.pose, frame: frameIndex, flipped: pose.flipped)
        petView.spriteFrame = frame
    }

    private func currentPose() -> (pose: DesktopPetPose, flipped: Bool) {
        if state.isRefreshing || state.phase == .limit {
            return (.alert, false)
        }

        if state.animationPaused {
            return (.idleFront, false)
        }

        if state.reducedMotion {
            return currentDirection().idlePose
        }

        return currentDirection().runPose
    }

    private func moveOneTick(elapsed: TimeInterval) -> Bool {
        guard !isDragging else {
            return false
        }
        guard let panel else { return false }
        var frame = panel.frame
        let visibleFrame = screenVisibleFrame(for: frame)
        let previousDirection = currentDirection()

        let maxTurn = Self.maxTurnRadiansPerSecond * CGFloat(elapsed)
        heading = Self.steppedAngle(from: heading, to: targetHeading, maxStep: maxTurn)

        let response = CGFloat(1 - exp(-Self.speedResponse * elapsed))
        speed += (targetSpeed - speed) * response

        frame.origin.x += cos(heading) * speed * CGFloat(elapsed)
        frame.origin.y += sin(heading) * speed * CGFloat(elapsed)

        if let safeHeading = FloatingPetMotionBounds.headingTowardSafeAreaIfNeeded(
            frame: frame,
            visibleFrame: visibleFrame
        ) {
            targetHeading = safeHeading
        }

        if frame.minX < visibleFrame.minX {
            frame.origin.x = visibleFrame.minX
            reflectHorizontally()
        } else if frame.maxX > visibleFrame.maxX {
            frame.origin.x = visibleFrame.maxX - frame.width
            reflectHorizontally()
        }

        if frame.minY < visibleFrame.minY {
            frame.origin.y = visibleFrame.minY
            reflectVertically()
        } else if frame.maxY > visibleFrame.maxY {
            frame.origin.y = visibleFrame.maxY - frame.height
            reflectVertically()
        }

        panel.setFrameOrigin(frame.origin)
        return previousDirection != currentDirection()
    }

    private func chooseNextMotionTarget() {
        targetSpeed = speedForCurrentState()
        guard targetSpeed > 0 else {
            speed = 0
            return
        }

        if let panel,
           let safeHeading = FloatingPetMotionBounds.headingTowardSafeAreaIfNeeded(
            frame: panel.frame,
            visibleFrame: screenVisibleFrame(for: panel.frame)
           ) {
            targetHeading = safeHeading
        } else {
            let turn = CGFloat.random(in: (-CGFloat.pi * 0.7)...(CGFloat.pi * 0.7))
            targetHeading = Self.normalizedAngle(heading + turn)
        }
        renderFrame()
    }

    private func retargetMotionForCurrentState() {
        targetSpeed = speedForCurrentState()
        guard targetSpeed > 0 else {
            speed = 0
            return
        }

        speed = max(speed, min(targetSpeed, 24))
    }

    private func speedForCurrentState() -> CGFloat {
        switch state.phase {
        case .calm:
            54
        case .active:
            72
        case .fast:
            92
        case .sprint:
            116
        case .limit:
            0
        }
    }

    private func desktopFrameInterval() -> TimeInterval {
        if state.reducedMotion {
            return 1.5
        }

        switch state.phase {
        case .calm, .active:
            return 0.12
        case .fast:
            return 0.09
        case .sprint:
            return 0.07
        case .limit:
            return 0.25
        }
    }

    private func restorePositionIfNeeded() {
        guard let panel else { return }
        var frame = panel.frame
        let savedOrigin = RunnerPreferences.desktopPetOrigin()
        frame.origin = savedOrigin ?? defaultOrigin()
        frame.origin = clamped(origin: frame.origin, size: frame.size)
        panel.setFrame(frame, display: true)
    }

    private func saveCurrentPosition() {
        guard let panel else { return }
        RunnerPreferences.setDesktopPetOrigin(panel.frame.origin)
    }

    private func moveDrag(delta: NSPoint, from startFrame: NSRect) {
        guard let panel else { return }
        var frame = startFrame
        frame.origin.x += delta.x
        frame.origin.y += delta.y
        frame.origin = FloatingPetMotionBounds.clamped(
            origin: frame.origin,
            size: frame.size,
            visibleFrame: screenVisibleFrame(for: frame)
        )
        panel.setFrame(frame, display: true)
    }

    private func finishDrag() {
        isDragging = false
        lastUpdateTimestamp = ProcessInfo.processInfo.systemUptime
        retargetElapsed = 0
        nextRetargetInterval = Self.randomRetargetInterval()

        guard let panel else { return }
        var frame = panel.frame
        let visibleFrame = screenVisibleFrame(for: frame)
        frame.origin = FloatingPetMotionBounds.clamped(
            origin: frame.origin,
            size: frame.size,
            visibleFrame: visibleFrame
        )
        panel.setFrame(frame, display: true)

        if let safeHeading = FloatingPetMotionBounds.headingTowardSafeAreaIfNeeded(
            frame: frame,
            visibleFrame: visibleFrame
        ) {
            heading = safeHeading
            targetHeading = safeHeading
        }

        saveCurrentPosition()
        renderFrame()
    }

    private func defaultOrigin() -> NSPoint {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 720)
        return NSPoint(
            x: visibleFrame.maxX - Self.petSize.width - 80,
            y: visibleFrame.minY + 80
        )
    }

    private func clamped(origin: NSPoint, size: NSSize) -> NSPoint {
        let frame = NSRect(origin: origin, size: size)
        return FloatingPetMotionBounds.clamped(
            origin: origin,
            size: size,
            visibleFrame: screenVisibleFrame(for: frame)
        )
    }

    private func screenVisibleFrame(for frame: NSRect) -> NSRect {
        let center = NSPoint(x: frame.midX, y: frame.midY)
        if let screen = NSScreen.screens.first(where: { $0.visibleFrame.contains(center) }) {
            return screen.visibleFrame
        }

        if let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(frame) }) {
            return screen.visibleFrame
        }

        return NSScreen.screens.min { lhs, rhs in
            Self.distanceSquared(from: center, to: lhs.visibleFrame) <
                Self.distanceSquared(from: center, to: rhs.visibleFrame)
        }?.visibleFrame ?? NSScreen.main?.visibleFrame ?? frame
    }

    private func showMenu(at point: NSPoint) {
        let menu = menuProvider(.desktop)
        guard let panel else {
            menu.popUp(positioning: nil, at: point, in: petView)
            return
        }

        let clickPoint = panel.convertToScreen(NSRect(origin: point, size: .zero)).origin
        let placement = FloatingPetMenuPlacement.resolve(
            petFrame: panel.frame,
            visibleFrame: screenVisibleFrame(for: panel.frame),
            clickPoint: clickPoint,
            menuSize: estimatedMenuSize(for: menu)
        )
        menu.popUp(positioning: nil, at: placement.origin, in: nil)
    }

    private func estimatedMenuSize(for menu: NSMenu) -> NSSize {
        let font = NSFont.menuFont(ofSize: 0)
        let widestTitle = menu.items
            .filter { !$0.isSeparatorItem }
            .map { ($0.title as NSString).size(withAttributes: [.font: font]).width }
            .max() ?? 0
        let itemHeights = menu.items.reduce(CGFloat.zero) { total, item in
            total + (item.isSeparatorItem ? 8 : 22)
        }

        return NSSize(
            width: max(180, ceil(widestTitle) + 64),
            height: max(44, itemHeights)
        )
    }

    private func currentDirection() -> DesktopPetMotionDirection {
        DesktopPetMotionDirection(heading: heading)
    }

    private func reflectHorizontally() {
        heading = Self.normalizedAngle(.pi - heading)
        targetHeading = Self.normalizedAngle(.pi - targetHeading)
    }

    private func reflectVertically() {
        heading = Self.normalizedAngle(-heading)
        targetHeading = Self.normalizedAngle(-targetHeading)
    }

    private static func steppedAngle(from current: CGFloat, to target: CGFloat, maxStep: CGFloat) -> CGFloat {
        let delta = atan2(sin(target - current), cos(target - current))
        let step = min(max(delta, -maxStep), maxStep)
        return normalizedAngle(current + step)
    }

    private static func normalizedAngle(_ angle: CGFloat) -> CGFloat {
        let fullTurn = CGFloat.pi * 2
        let normalized = angle.truncatingRemainder(dividingBy: fullTurn)
        return normalized < 0 ? normalized + fullTurn : normalized
    }

    private static func distanceSquared(from point: NSPoint, to rect: NSRect) -> CGFloat {
        let dx: CGFloat
        if point.x < rect.minX {
            dx = rect.minX - point.x
        } else if point.x > rect.maxX {
            dx = point.x - rect.maxX
        } else {
            dx = 0
        }

        let dy: CGFloat
        if point.y < rect.minY {
            dy = rect.minY - point.y
        } else if point.y > rect.maxY {
            dy = point.y - rect.maxY
        } else {
            dy = 0
        }

        return dx * dx + dy * dy
    }

    private static func randomRetargetInterval() -> TimeInterval {
        TimeInterval.random(in: retargetRange)
    }
}

struct FloatingPetMotionBounds {
    static func clamped(origin: NSPoint, size: NSSize, visibleFrame: NSRect) -> NSPoint {
        NSPoint(
            x: min(max(origin.x, visibleFrame.minX), visibleFrame.maxX - size.width),
            y: min(max(origin.y, visibleFrame.minY), visibleFrame.maxY - size.height)
        )
    }

    static func headingTowardSafeAreaIfNeeded(
        frame: NSRect,
        visibleFrame: NSRect,
        margin: CGFloat = 80
    ) -> CGFloat? {
        let safeFrame = visibleFrame.insetBy(
            dx: min(margin, max(0, visibleFrame.width / 2 - 1)),
            dy: min(margin, max(0, visibleFrame.height / 2 - 1))
        )
        let center = NSPoint(x: frame.midX, y: frame.midY)
        guard !safeFrame.contains(center) else { return nil }

        let target = NSPoint(
            x: min(max(center.x, safeFrame.minX), safeFrame.maxX),
            y: min(max(center.y, safeFrame.minY), safeFrame.maxY)
        )
        return atan2(target.y - center.y, target.x - center.x)
    }
}

struct FloatingPetMenuPlacement: Equatable {
    enum Side: Equatable {
        case left
        case right
    }

    let origin: NSPoint
    let side: Side

    static func resolve(
        petFrame: NSRect,
        visibleFrame: NSRect,
        clickPoint: NSPoint,
        menuSize: NSSize,
        padding: CGFloat = 8
    ) -> FloatingPetMenuPlacement {
        let safeFrame = visibleFrame.insetBy(dx: padding, dy: padding)
        let side: Side = petFrame.midX <= safeFrame.midX ? .right : .left
        let rawX: CGFloat = side == .right
            ? petFrame.maxX + padding
            : petFrame.minX - menuSize.width - padding
        let maxX = max(safeFrame.minX, safeFrame.maxX - menuSize.width)
        let x = min(max(rawX, safeFrame.minX), maxX)

        let menuHeight = max(menuSize.height, 1)
        let rawY = clickPoint.y + min(menuHeight * 0.5, petFrame.height * 0.5)
        let minY = min(safeFrame.maxY, safeFrame.minY + menuHeight)
        let y = min(max(rawY, minY), safeFrame.maxY)

        return FloatingPetMenuPlacement(origin: NSPoint(x: x, y: y), side: side)
    }
}

private enum DesktopPetMotionDirection: Equatable {
    case right
    case left
    case up
    case down

    init(heading: CGFloat) {
        let dx = cos(heading)
        let dy = sin(heading)

        if abs(dx) >= abs(dy) {
            self = dx >= 0 ? .right : .left
        } else {
            self = dy >= 0 ? .up : .down
        }
    }

    var runPose: (pose: DesktopPetPose, flipped: Bool) {
        switch self {
        case .right:
            return (.runRight, false)
        case .left:
            return (.runRight, true)
        case .up:
            return (.runUp, false)
        case .down:
            return (.runDown, false)
        }
    }

    var idlePose: (pose: DesktopPetPose, flipped: Bool) {
        switch self {
        case .right:
            return (.idleSide, false)
        case .left:
            return (.idleSide, true)
        case .up, .down:
            return (.idleFront, false)
        }
    }
}

private final class FloatingPetView: NSView {
    var spriteFrame: DesktopPetFrame? {
        didSet { needsDisplay = true }
    }
    var onClick: (() -> Void)?
    var onRightClick: ((NSPoint) -> Void)?
    var onDragStarted: (() -> Void)?
    var onDragMoved: ((NSPoint, NSRect) -> Void)?
    var onDragEnded: (() -> Void)?
    private var dragStartScreenLocation: NSPoint?
    private var dragStartFrame: NSRect?
    private var didDrag = false

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        bounds.fill()

        guard let spriteFrame else { return }
        let image = spriteFrame.image
        let offset = spriteFrame.offset
        let scaleX = bounds.width / max(image.size.width, 1)
        let scaleY = bounds.height / max(image.size.height, 1)
        let drawRect = bounds.offsetBy(dx: offset.x * scaleX, dy: offset.y * scaleY)
        image.draw(in: drawRect)
    }

    override func mouseDown(with event: NSEvent) {
        dragStartScreenLocation = NSEvent.mouseLocation
        dragStartFrame = window?.frame
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, let dragStartScreenLocation, let dragStartFrame else { return }
        let current = NSEvent.mouseLocation
        let delta = NSPoint(x: current.x - dragStartScreenLocation.x, y: current.y - dragStartScreenLocation.y)
        guard abs(delta.x) > 2 || abs(delta.y) > 2 else { return }
        if !didDrag {
            onDragStarted?()
            didDrag = true
        }
        if let onDragMoved {
            onDragMoved(delta, dragStartFrame)
        } else {
            var frame = dragStartFrame
            frame.origin.x += delta.x
            frame.origin.y += delta.y
            window.setFrame(frame, display: true)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if didDrag {
            onDragEnded?()
        } else {
            onClick?()
        }

        dragStartScreenLocation = nil
        dragStartFrame = nil
        didDrag = false
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?(event.locationInWindow)
    }
}
