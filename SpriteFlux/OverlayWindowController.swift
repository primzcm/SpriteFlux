import Cocoa

final class OverlayWindowController: NSWindowController {
    struct StateSnapshot {
        let id: String
        let origin: NSPoint
        let scale: Double
        let opacity: Double
        let moveModeEnabled: Bool
        let clickThroughEnabled: Bool
    }

    let companionID: String
    private let overlayView = OverlayView()

    private let defaultSize = CGSize(width: 300, height: 300)
    private let maxDimension: CGFloat = 360
    private let minDimension: CGFloat = 120
    private var currentMediaSize: CGSize = CGSize(width: 300, height: 300)
    private(set) var clickThroughEnabled: Bool
    private(set) var isMoveModeEnabled: Bool
    private(set) var currentMediaURL: URL?
    private var scale: Double
    private var opacity: Double
    private let initialOrigin: NSPoint?
    private let defaultOriginOffsetIndex: Int

    var onStateChange: ((StateSnapshot) -> Void)?

    init(
        companionID: String,
        initialMediaURL: URL?,
        initialScale: Double,
        initialOpacity: Double,
        clickThroughEnabled: Bool,
        moveModeEnabled: Bool,
        initialOrigin: NSPoint?,
        defaultOriginOffsetIndex: Int
    ) {
        self.companionID = companionID
        self.currentMediaURL = initialMediaURL
        self.scale = initialScale
        self.opacity = initialOpacity
        self.clickThroughEnabled = clickThroughEnabled
        self.isMoveModeEnabled = moveModeEnabled
        self.initialOrigin = initialOrigin
        self.defaultOriginOffsetIndex = defaultOriginOffsetIndex
        let size = defaultSize
        let origin = initialOrigin ?? OverlayWindowController.defaultOrigin(for: size, offsetIndex: defaultOriginOffsetIndex)
        let window = NSWindow(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentView = overlayView
        window.alphaValue = CGFloat(initialOpacity)

        super.init(window: window)

        if let initialMediaURL {
            _ = loadMedia(url: initialMediaURL)
        } else {
            resizeWindow()
        }
        applySavedPosition()
        applyInteractionMode()
        emitStateChange()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification,
            object: window
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        if window == nil {
            _ = self.window
        }
        window?.orderFrontRegardless()
    }

    @discardableResult
    func loadMedia(url: URL) -> Bool {
        guard let size = overlayView.loadMedia(url: url) else {
            return false
        }

        currentMediaSize = size
        currentMediaURL = url
        resizeWindow()
        emitStateChange()
        return true
    }

    func toggleMoveMode() {
        let newValue = !isMoveModeEnabled
        isMoveModeEnabled = newValue

        if newValue {
            clickThroughEnabled = false
        } else {
            clickThroughEnabled = true
        }

        applyInteractionMode()
        emitStateChange()
    }

    func toggleClickThrough() {
        let newValue = !clickThroughEnabled
        clickThroughEnabled = newValue

        if newValue {
            isMoveModeEnabled = false
        }

        applyInteractionMode()
        emitStateChange()
    }

    func resetPosition() {
        guard let window = window else {
            return
        }

        let origin = OverlayWindowController.defaultOrigin(for: window.frame.size, offsetIndex: defaultOriginOffsetIndex)
        window.setFrameOrigin(origin)
        emitStateChange()
    }

    func setScale(_ scale: Double) {
        self.scale = scale
        resizeWindow()
        emitStateChange()
    }

    func setOpacity(_ opacity: Double) {
        self.opacity = opacity
        window?.alphaValue = CGFloat(opacity)
        emitStateChange()
    }

    func clearMedia() {
        currentMediaSize = defaultSize
        currentMediaURL = nil
        overlayView.clearContent()
        resizeWindow()
        emitStateChange()
    }

    private func applyInteractionMode() {
        guard let window = window else {
            return
        }

        let ignoresClicks = clickThroughEnabled && !isMoveModeEnabled
        window.ignoresMouseEvents = ignoresClicks
        window.isMovableByWindowBackground = false
    }

    private func resizeWindow() {
        guard let window = window else {
            return
        }

        let size = normalizedSize(for: currentMediaSize)
        var frame = window.frame
        frame.size = size
        window.setFrame(frame, display: true)
        clampWindowToVisibleFrame()
    }

    private func normalizedSize(for mediaSize: CGSize) -> CGSize {
        guard mediaSize.width > 1, mediaSize.height > 1 else {
            return defaultSize
        }

        let maxSide = max(mediaSize.width, mediaSize.height)
        let scaleRatio = min(1.0, maxDimension / maxSide)
        var scaled = CGSize(width: mediaSize.width * scaleRatio, height: mediaSize.height * scaleRatio)

        let currentMax = max(scaled.width, scaled.height)
        if currentMax < minDimension {
            let upScale = minDimension / currentMax
            scaled = CGSize(width: scaled.width * upScale, height: scaled.height * upScale)
        }

        let userScale = CGFloat(scale)
        return CGSize(width: scaled.width * userScale, height: scaled.height * userScale)
    }

    private func clampWindowToVisibleFrame() {
        guard let window = window,
              let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame else {
            return
        }

        var frame = window.frame

        if frame.minX < screenFrame.minX {
            frame.origin.x = screenFrame.minX
        }
        if frame.minY < screenFrame.minY {
            frame.origin.y = screenFrame.minY
        }
        if frame.maxX > screenFrame.maxX {
            frame.origin.x = screenFrame.maxX - frame.width
        }
        if frame.maxY > screenFrame.maxY {
            frame.origin.y = screenFrame.maxY - frame.height
        }

        window.setFrame(frame, display: true)
        emitStateChange()
    }

    private func applySavedPosition() {
        guard let window = window else {
            return
        }

        if let initialOrigin {
            let candidate = NSRect(origin: initialOrigin, size: window.frame.size)
            let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
            if let screenFrame = screenFrame, screenFrame.intersects(candidate) {
                window.setFrameOrigin(initialOrigin)
                return
            }
        }

        let origin = OverlayWindowController.defaultOrigin(for: window.frame.size, offsetIndex: defaultOriginOffsetIndex)
        window.setFrameOrigin(origin)
    }

    @objc private func windowDidMove(_ notification: Notification) {
        guard window != nil else {
            return
        }

        emitStateChange()
    }

    private static func defaultOrigin(for size: CGSize, offsetIndex: Int) -> NSPoint {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let offset = CGFloat(offsetIndex % 6) * 28
        let x = screenFrame.maxX - size.width - 40 - offset
        let y = screenFrame.midY - size.height / 2 - offset
        return NSPoint(x: max(screenFrame.minX, x), y: max(screenFrame.minY, y))
    }

    private func emitStateChange() {
        guard let window else {
            return
        }

        let snapshot = StateSnapshot(
            id: companionID,
            origin: window.frame.origin,
            scale: scale,
            opacity: opacity,
            moveModeEnabled: isMoveModeEnabled,
            clickThroughEnabled: clickThroughEnabled
        )
        onStateChange?(snapshot)
    }
}
