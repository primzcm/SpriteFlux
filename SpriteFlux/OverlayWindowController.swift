import Cocoa

final class OverlayWindowController: NSWindowController {
    private let settings = SettingsManager.shared
    private let overlayView = OverlayView()

    private let defaultSize = CGSize(width: 300, height: 300)
    private let maxDimension: CGFloat = 360
    private let minDimension: CGFloat = 120

    var clickThroughEnabled: Bool {
        settings.clickThroughEnabled
    }

    var isMoveModeEnabled: Bool {
        settings.isMoveMode
    }

    init() {
        let size = defaultSize
        let origin = OverlayWindowController.initialOrigin(for: size)
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

        super.init(window: window)

        applySavedPosition()
        applyInteractionMode()

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

        settings.lastFileURL = url
        resizeWindow(for: size)
        return true
    }

    func toggleMoveMode() {
        let newValue = !settings.isMoveMode
        settings.isMoveMode = newValue

        if newValue {
            settings.clickThroughEnabled = false
        } else {
            settings.clickThroughEnabled = true
        }

        applyInteractionMode()
    }

    func toggleClickThrough() {
        let newValue = !settings.clickThroughEnabled
        settings.clickThroughEnabled = newValue

        if newValue {
            settings.isMoveMode = false
        }

        applyInteractionMode()
    }

    func resetPosition() {
        guard let window = window else {
            return
        }

        let origin = OverlayWindowController.defaultOrigin(for: window.frame.size)
        window.setFrameOrigin(origin)
        settings.lastWindowOrigin = origin
    }

    private func applyInteractionMode() {
        guard let window = window else {
            return
        }

        let ignoresClicks = settings.clickThroughEnabled && !settings.isMoveMode
        window.ignoresMouseEvents = ignoresClicks
        window.isMovableByWindowBackground = false
    }

    private func resizeWindow(for mediaSize: CGSize) {
        guard let window = window else {
            return
        }

        let size = normalizedSize(for: mediaSize)
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
        var scale = min(1.0, maxDimension / maxSide)
        var scaled = CGSize(width: mediaSize.width * scale, height: mediaSize.height * scale)

        let currentMax = max(scaled.width, scaled.height)
        if currentMax < minDimension {
            let upScale = minDimension / currentMax
            scaled = CGSize(width: scaled.width * upScale, height: scaled.height * upScale)
        }

        return scaled
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
        settings.lastWindowOrigin = frame.origin
    }

    private func applySavedPosition() {
        guard let window = window else {
            return
        }

        if let saved = settings.lastWindowOrigin {
            let candidate = NSRect(origin: saved, size: window.frame.size)
            let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
            if let screenFrame = screenFrame, screenFrame.intersects(candidate) {
                window.setFrameOrigin(saved)
                return
            }
        }

        let origin = OverlayWindowController.defaultOrigin(for: window.frame.size)
        window.setFrameOrigin(origin)
    }

    @objc private func windowDidMove(_ notification: Notification) {
        guard let window = window else {
            return
        }

        settings.lastWindowOrigin = window.frame.origin
    }

    private static func initialOrigin(for size: CGSize) -> NSPoint {
        let settings = SettingsManager.shared
        if let saved = settings.lastWindowOrigin {
            return saved
        }
        return defaultOrigin(for: size)
    }

    private static func defaultOrigin(for size: CGSize) -> NSPoint {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let x = screenFrame.maxX - size.width - 40
        let y = screenFrame.midY - size.height / 2
        return NSPoint(x: max(screenFrame.minX, x), y: max(screenFrame.minY, y))
    }
}
