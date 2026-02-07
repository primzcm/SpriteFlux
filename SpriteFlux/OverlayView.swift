import Cocoa

final class OverlayView: NSView {
    private var currentView: NSView?

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
}
