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
        vc.applyPipState()
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerLayerViewController, context: Context) {
        vc.isPipRequested = pipEnabled
        vc.autoPip = autoPip
        vc.onPipChanged = onPipChanged
        vc.applyPipState()
    }
}

// MARK: - AVPlayerLayerViewController

final class AVPlayerLayerViewController: UIViewController, AVPictureInPictureControllerDelegate {
    let playerLayer = AVPlayerLayer()
    private(set) var pipController: AVPictureInPictureController?

    var onPipChanged: ((Bool) -> Void)?
    var isPipRequested = false
    var autoPip = true

    /// True from `willStart` until PiP is gone again. `isPictureInPictureActive` is still false while
    /// the transition is in flight, which is exactly when backgrounding has to make its decision.
    private var isPipStarting = false
    private var pipPossibleObservation: NSKeyValueObservation?

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
    //
    // The controller only exists while it can be needed. Auto-PiP needs one sitting inline to start
    // from, but with auto-PiP off an inline controller is a liability: iOS commits to starting PiP
    // before the app hears about backgrounding, so clearing
    // `canStartPictureInPictureAutomaticallyFromInline` or releasing the controller comes too late —
    // the window would briefly appear and get torn down again. Without a controller there's nothing
    // to start in the first place.

    func applyPipState() {
        if isPipRequested || autoPip {
            setUpPip()
        } else if !isPipStarting, pipController?.isPictureInPictureActive != true {
            tearDownPip()
        }

        guard let pip = pipController else { return }
        pip.canStartPictureInPictureAutomaticallyFromInline = autoPip
        if isPipRequested && !pip.isPictureInPictureActive && !isPipStarting {
            startPipWhenPossible()
        } else if !isPipRequested && pip.isPictureInPictureActive {
            pip.stopPictureInPicture()
        }
    }

    private func setUpPip() {
        guard pipController == nil, AVPictureInPictureController.isPictureInPictureSupported() else { return }
        let pip = AVPictureInPictureController(playerLayer: playerLayer)
        pip?.canStartPictureInPictureAutomaticallyFromInline = autoPip
        pip?.delegate = self
        pipController = pip
    }

    private func tearDownPip() {
        pipPossibleObservation?.invalidate()
        pipPossibleObservation = nil
        pipController = nil
    }

    /// A just-created controller reports `isPictureInPicturePossible == false` for a moment, so a PiP
    /// the user asked for has to wait for it instead of being dropped.
    private func startPipWhenPossible() {
        guard let pip = pipController else { return }
        if pip.isPictureInPicturePossible {
            pip.startPictureInPicture()
            return
        }
        guard pipPossibleObservation == nil else { return }
        pipPossibleObservation = pip.observe(\.isPictureInPicturePossible) { [weak self] _, _ in
            Task { @MainActor in
                guard let self,
                      let pip = self.pipController,
                      pip.isPictureInPicturePossible else { return }
                self.pipPossibleObservation?.invalidate()
                self.pipPossibleObservation = nil
                guard self.isPipRequested, !pip.isPictureInPictureActive, !self.isPipStarting else { return }
                pip.startPictureInPicture()
            }
        }
    }

    func pictureInPictureControllerWillStartPictureInPicture(_ pip: AVPictureInPictureController) {
        isPipStarting = true
        // AVKit's ordering against `didEnterBackground` isn't guaranteed, so the background detach
        // may have won the race; hand the layer its player back so PiP has something to render.
        reattachPlayer()
        onPipChanged?(true)
    }

    func pictureInPictureControllerWillStopPictureInPicture(_ pip: AVPictureInPictureController) {
        isPipStarting = false
        onPipChanged?(false)
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pip: AVPictureInPictureController) {
        // Back inline; with auto-PiP off nothing should be left that could start PiP unprompted.
        if !autoPip && !isPipRequested {
            tearDownPip()
        }
    }

    func pictureInPictureController(
        _ pip: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        isPipStarting = false
        onPipChanged?(false)
        // Backgrounded with no PiP window after all: fall back to audio-only so playback survives.
        if UIApplication.shared.applicationState == .background {
            detachForBackground()
        }
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
                forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
            ) { [weak self] _ in self?.detachForBackground() },
            center.addObserver(
                forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main
            ) { [weak self] _ in self?.reattachPlayer() }
        ]
    }

    private func detachForBackground() {
        // PiP renders from this layer; detaching would kill the PiP window. Only an actual start
        // counts — auto-PiP fires when the user leaves the app but never on screen lock, so keying
        // off `autoPip` (or PiP merely being possible) would strand a locked screen with an attached
        // layer, which iOS then pauses.
        guard !isPipRequested, !isPipStarting, pipController?.isPictureInPictureActive != true else { return }
        guard let player = playerLayer.player else { return }
        detachedPlayer = player
        playerLayer.player = nil
    }

    private func reattachPlayer() {
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
