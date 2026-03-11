import Cocoa
import AVFoundation

final class VideoPlayerView: NSView {
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var playerLayer: AVPlayerLayer?

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

    func load(url: URL) -> CGSize? {
        let asset = AVAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        let queuePlayer = AVQueuePlayer()
        let looper = AVPlayerLooper(player: queuePlayer, templateItem: item)

        let layer = AVPlayerLayer(player: queuePlayer)
        layer.videoGravity = .resizeAspect

        self.layer?.sublayers?.removeAll()
        self.layer?.addSublayer(layer)
        self.playerLayer = layer
        self.player = queuePlayer
        self.looper = looper

        queuePlayer.play()

        if let track = asset.tracks(withMediaType: .video).first {
            let transformed = track.naturalSize.applying(track.preferredTransform)
            return CGSize(width: abs(transformed.width), height: abs(transformed.height))
        }

        return nil
    }

    override func layout() {
        super.layout()
        playerLayer?.frame = bounds
    }
}
