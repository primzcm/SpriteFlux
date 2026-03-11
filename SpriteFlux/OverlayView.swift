import Cocoa

final class OverlayView: NSView {
    private var currentView: NSView?
    private var dragStartLocation: NSPoint?
    private var dragStartOrigin: NSPoint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    func loadMedia(url: URL) -> CGSize? {
        let ext = url.pathExtension.lowercased()
        if ["mp4", "mov"].contains(ext) {
            let view = VideoPlayerView()
            let size = view.load(url: url)
            setContentView(view)
            return size
        }

        if ext == "gif" {
            let view = GIFPlayerView()
            let size = view.load(url: url)
            setContentView(view)
            return size
        }

        return nil
    }

    private func setContentView(_ view: NSView) {
        currentView?.removeFromSuperview()
        currentView = view

        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)

        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor),
            view.topAnchor.constraint(equalTo: topAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    override func mouseDown(with event: NSEvent) {
        guard let window = window else {
            return
        }
        dragStartLocation = NSEvent.mouseLocation
        dragStartOrigin = window.frame.origin
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = window,
              let startLocation = dragStartLocation,
              let startOrigin = dragStartOrigin else {
            return
        }

        let currentLocation = NSEvent.mouseLocation
        let deltaX = currentLocation.x - startLocation.x
        let deltaY = currentLocation.y - startLocation.y

        let newOrigin = NSPoint(x: startOrigin.x + deltaX, y: startOrigin.y + deltaY)
        window.setFrameOrigin(newOrigin)
    }

    override func mouseUp(with event: NSEvent) {
        dragStartLocation = nil
        dragStartOrigin = nil
    }
}
