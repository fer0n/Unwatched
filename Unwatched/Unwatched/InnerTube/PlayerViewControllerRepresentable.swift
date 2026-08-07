#if !os(macOS)
import AVKit
import SwiftUI

// MARK: - PlayerViewControllerRepresentable

struct PlayerViewControllerRepresentable: UIViewControllerRepresentable {
    let avPlayer: AVPlayer
    let pipEnabled: Bool
    /// Leaving the app enters PiP when on, and keeps playing audio only when off.
    let autoPip: Bool
    let onPipChanged: (Bool) -> Void

    func makeUIViewController(context: Context) -> AVPlayerLayerViewController {
        let vc = AVPlayerLayerViewController()
        vc.playerLayer.player = avPlayer
        vc.autoPip = autoPip
        vc.onPipChanged = onPipChanged
        vc.setUpPip()
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerLayerViewController, context: Context) {
        vc.isPipRequested = pipEnabled
        vc.autoPip = autoPip
        vc.onPipChanged = onPipChanged

        guard let pip = vc.pipController else { return }
        pip.canStartPictureInPictureAutomaticallyFromInline = autoPip
        if pipEnabled && !pip.isPictureInPictureActive && pip.isPictureInPicturePossible {
            pip.startPictureInPicture()
        } else if !pipEnabled && pip.isPictureInPictureActive {
            pip.stopPictureInPicture()
        }
    }
}

// MARK: - AVPlayerLayerViewController

final class AVPlayerLayerViewController: UIViewController, AVPictureInPictureControllerDelegate {
    let playerLayer = AVPlayerLayer()
    private(set) var pipController: AVPictureInPictureController?

    var onPipChanged: ((Bool) -> Void)?
    var isPipRequested = false
    var autoPip = true

    /// Holds the player while it's detached for the background; nil while attached.
    private var detachedPlayer: AVPlayer?
    private var lifecycleObservers: [NSObjectProtocol] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        playerLayer.videoGravity = .resizeAspect
        view.layer.addSublayer(playerLayer)
        observeAppLifecycle()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer.frame = view.bounds
    }

    deinit {
        lifecycleObservers.forEach(NotificationCenter.default.removeObserver)
    }

    // MARK: - PiP

    func setUpPip() {
        guard pipController == nil, AVPictureInPictureController.isPictureInPictureSupported() else { return }
        let pip = AVPictureInPictureController(playerLayer: playerLayer)
        pip?.canStartPictureInPictureAutomaticallyFromInline = autoPip
        pip?.delegate = self
        pipController = pip
    }

    /// AVKit commits to auto-PiP before `didEnterBackground`, too late to call off by clearing
    /// `canStartPictureInPictureAutomaticallyFromInline`. Releasing the controller leaves nothing
    /// that could start it, and doesn't touch the layer, so a Control Center pull stays untouched.
    private func dropPipForAudioOnly() {
        guard !autoPip, !isPipRequested, pipController?.isPictureInPictureActive != true else { return }
        pipController = nil
    }

    func pictureInPictureControllerWillStartPictureInPicture(_ pip: AVPictureInPictureController) {
        onPipChanged?(true)
    }

    func pictureInPictureControllerWillStopPictureInPicture(_ pip: AVPictureInPictureController) {
        onPipChanged?(false)
    }

    // MARK: - Background detach
    //
    // iOS pauses an AVPlayer that still renders into a layer as soon as the app is backgrounded —
    // screen lock included — no matter what the `audio` background mode says. Detaching the layer
    // leaves an audio-only player, which keeps playing and skips video decode while the screen is off.

    private func observeAppLifecycle() {
        let center = NotificationCenter.default
        lifecycleObservers = [
            center.addObserver(
                forName: UIApplication.willResignActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in self?.dropPipForAudioOnly() },
            center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
            ) { [weak self] _ in self?.detachForBackground() },
            center.addObserver(
                forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main
            ) { [weak self] _ in self?.reattachForForeground() },
            center.addObserver(
                forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in self?.setUpPip() }
        ]
    }

    private func detachForBackground() {
        // PiP renders from this layer; detaching would kill the PiP window. Its state isn't settled
        // yet at this point, so `autoPip` decides — with it off the controller is already gone.
        guard !isPipRequested, pipController?.isPictureInPictureActive != true else { return }
        guard !autoPip || pipController?.isPictureInPicturePossible != true else { return }
        guard let player = playerLayer.player else { return }
        detachedPlayer = player
        playerLayer.player = nil
    }

    private func reattachForForeground() {
        guard let player = detachedPlayer else { return }
        playerLayer.player = player
        detachedPlayer = nil
    }
}

// MARK: - SeekAnchor

// Tracks the intended seek target between rapid seeks so relative seeks don't
// re-read avPlayer.currentTime(), which lags behind until a seek completes.
final class SeekAnchor {
    var time: Double?
}
#endif
