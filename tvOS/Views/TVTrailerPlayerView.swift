import SwiftUI
import AVKit
import AVFoundation

public struct TVTrailerPlayerView: UIViewRepresentable {
    public let videoURL: URL
    public let isMuted: Bool
    
    public init(videoURL: URL, isMuted: Bool = false) {
        self.videoURL = videoURL
        self.isMuted = isMuted
    }
    
    public func makeUIView(context: Context) -> TVTrailerPlayerUIView {
        let view = TVTrailerPlayerUIView()
        view.load(url: videoURL, isMuted: isMuted)
        return view
    }
    
    public func updateUIView(_ uiView: TVTrailerPlayerUIView, context: Context) {
        if uiView.currentURL != videoURL {
            uiView.load(url: videoURL, isMuted: isMuted)
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
    
    public func load(url: URL, isMuted: Bool) {
        tearDown()
        currentURL = url
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Non-fatal if audio session is active
        }
        
        let playerItem = AVPlayerItem(url: url)
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
            self?.player?.seek(to: .zero)
            self?.player?.play()
        }
        
        statusObservation = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                if item.status == .readyToPlay {
                    UIView.animate(withDuration: 0.35) {
                        self?.alpha = 1.0
                    }
                    self?.player?.play()
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
