import Cocoa

final class GIFPlayerView: NSView {
    private let imageView = NSImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    private func configureView() {
        wantsLayer = true
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func load(url: URL) -> CGSize? {
        guard let image = NSImage(contentsOf: url) else {
            return nil
        }
        imageView.image = image
        imageView.animates = true
        return image.size
    }
}
