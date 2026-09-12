import SwiftUI
import AVKit
import AVFoundation

public struct TVTrailerPlayerView: UIViewRepresentable {
    public let videoURL: URL
    public let isMuted: Bool
    public let loopPlayback: Bool
    public let onReadyToPlay: (() -> Void)?
    public let onPlaybackEnded: (() -> Void)?
    
    public init(
        videoURL: URL,
        isMuted: Bool = false,
        loopPlayback: Bool = false,
        onReadyToPlay: (() -> Void)? = nil,
        onPlaybackEnded: (() -> Void)? = nil
    ) {
        self.videoURL = videoURL
        self.isMuted = isMuted
        self.loopPlayback = loopPlayback
        self.onReadyToPlay = onReadyToPlay
        self.onPlaybackEnded = onPlaybackEnded
    }
    
    public func makeUIView(context: Context) -> TVTrailerPlayerUIView {
        let view = TVTrailerPlayerUIView()
        view.load(url: videoURL, isMuted: isMuted, loopPlayback: loopPlayback, onReadyToPlay: onReadyToPlay, onPlaybackEnded: onPlaybackEnded)
        return view
    }
    
    public func updateUIView(_ uiView: TVTrailerPlayerUIView, context: Context) {
        uiView.onReadyToPlay = onReadyToPlay
        uiView.onPlaybackEnded = onPlaybackEnded
        uiView.loopPlayback = loopPlayback
        if uiView.currentURL != videoURL {
            uiView.load(url: videoURL, isMuted: isMuted, loopPlayback: loopPlayback, onReadyToPlay: onReadyToPlay, onPlaybackEnded: onPlaybackEnded)
        }
    }
    
    public static func dismantleUIView(_ uiView: TVTrailerPlayerUIView, coordinator: ()) {
        uiView.tearDown()
    }
}

public final class TVTrailerPlayerUIView: UIView {
    override public static var layerClass: AnyClass {
        AVPlayerLayer.self
    }
    
    private var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
    
    public private(set) var currentURL: URL?
    public var onReadyToPlay: (() -> Void)?
    public var onPlaybackEnded: (() -> Void)?
    public var loopPlayback: Bool = false
    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = .clear
        isUserInteractionEnabled = false
        playerLayer.videoGravity = .resizeAspectFill
        alpha = 0.0
    }
    
    public func load(url: URL, isMuted: Bool, loopPlayback: Bool = false, onReadyToPlay: (() -> Void)? = nil, onPlaybackEnded: (() -> Void)? = nil) {
        tearDown()
        currentURL = url
        self.loopPlayback = loopPlayback
        self.onReadyToPlay = onReadyToPlay
        self.onPlaybackEnded = onPlaybackEnded
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Non-fatal if audio session is active
        }
        
        let playerItem = AVPlayerItem(url: url)
        // Ensure highest quality streaming up to 1080p full HD with zero bitrate cap
        playerItem.preferredMaximumResolution = CGSize(width: 1920, height: 1080)
        playerItem.preferredPeakBitRate = 0
        
        let newPlayer = AVPlayer(playerItem: playerItem)
        newPlayer.isMuted = isMuted
        newPlayer.automaticallyWaitsToMinimizeStalling = false
        
        player = newPlayer
        playerLayer.player = newPlayer
        
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            if self.loopPlayback {
                self.player?.seek(to: .zero)
                self.player?.play()
            } else {
                self.onPlaybackEnded?()
            }
        }
        
        statusObservation = playerItem.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                if item.status == .readyToPlay {
                    UIView.animate(withDuration: 0.35) {
                        self?.alpha = 1.0
                    }
                    self?.player?.play()
                    self?.onReadyToPlay?()
                }
            }
        }
        
        newPlayer.play()
    }
    
    public func tearDown() {
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
        statusObservation?.invalidate()
        statusObservation = nil
        
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
        playerLayer.player = nil
        currentURL = nil
        alpha = 0.0
    }
    
    deinit {
        tearDown()
    }
}
