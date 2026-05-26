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
        petView.onDragEnded = { [weak self] in
            self?.isDragging = false
            self?.lastUpdateTimestamp = ProcessInfo.processInfo.systemUptime
            self?.saveCurrentPosition()
        }
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

        let turn = CGFloat.random(in: (-CGFloat.pi * 0.7)...(CGFloat.pi * 0.7))
        targetHeading = Self.normalizedAngle(heading + turn)
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

    private func defaultOrigin() -> NSPoint {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 720)
        return NSPoint(
            x: visibleFrame.maxX - Self.petSize.width - 80,
            y: visibleFrame.minY + 80
        )
    }

    private func clamped(origin: NSPoint, size: NSSize) -> NSPoint {
        let visibleFrame = NSScreen.screens
            .first { $0.visibleFrame.insetBy(dx: -40, dy: -40).contains(origin) }?
            .visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        return NSPoint(
            x: min(max(origin.x, visibleFrame.minX), visibleFrame.maxX - size.width),
            y: min(max(origin.y, visibleFrame.minY), visibleFrame.maxY - size.height)
        )
    }

    private func screenVisibleFrame(for frame: NSRect) -> NSRect {
        NSScreen.screens
            .first { $0.visibleFrame.intersects(frame) }?
            .visibleFrame ?? NSScreen.main?.visibleFrame ?? frame
    }

    private func showMenu(at point: NSPoint) {
        let menu = menuProvider(.desktop)
        menu.popUp(positioning: nil, at: point, in: petView)
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

    private static func randomRetargetInterval() -> TimeInterval {
        TimeInterval.random(in: retargetRange)
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
        var frame = dragStartFrame
        frame.origin.x += delta.x
        frame.origin.y += delta.y
        window.setFrame(frame, display: true)
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
