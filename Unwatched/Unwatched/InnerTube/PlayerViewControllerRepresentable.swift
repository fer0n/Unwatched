import AVKit
import SwiftUI

// MARK: - PlayerLayerController
//
// The PiP and player-layer plumbing shared by the UIKit and AppKit hosts below.
//
// The PiP controller only exists while it can be needed. Auto-PiP needs one sitting inline to start
// from, but with auto-PiP off an inline controller is a liability: iOS commits to starting PiP
// before the app hears about backgrounding, so clearing
// `canStartPictureInPictureAutomaticallyFromInline` or releasing the controller comes too late —
// the window would briefly appear and get torn down again. Without a controller there's nothing
// to start in the first place.

@MainActor
final class PlayerLayerController: NSObject, AVPictureInPictureControllerDelegate {
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

    override init() {
        super.init()
        playerLayer.videoGravity = .resizeAspect
        observeAppLifecycle()
    }

    deinit {
        lifecycleObservers.forEach(NotificationCenter.default.removeObserver)
    }

    // MARK: - PiP

    func applyPipState() {
        if isPipRequested || autoPip {
            setUpPip()
        } else if !isPipStarting, pipController?.isPictureInPictureActive != true {
            tearDownPip()
        }

        guard let pip = pipController else { return }
        #if !os(macOS)
        pip.canStartPictureInPictureAutomaticallyFromInline = autoPip
        #endif
        if isPipRequested && !pip.isPictureInPictureActive && !isPipStarting {
            startPipWhenPossible()
        } else if !isPipRequested && pip.isPictureInPictureActive {
            pip.stopPictureInPicture()
        }
    }

    private func setUpPip() {
        guard pipController == nil, AVPictureInPictureController.isPictureInPictureSupported() else { return }
        let pip = AVPictureInPictureController(playerLayer: playerLayer)
        #if !os(macOS)
        pip?.canStartPictureInPictureAutomaticallyFromInline = autoPip
        #endif
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
        #if !os(macOS)
        // Backgrounded with no PiP window after all: fall back to audio-only so playback survives.
        if UIApplication.shared.applicationState == .background {
            detachForBackground()
        }
        #endif
    }

    // MARK: - Background detach
    //
    // iOS pauses an AVPlayer that still renders into a layer as soon as the app is backgrounded —
    // screen lock included — no matter what the `audio` background mode says. Detaching the layer
    // leaves an audio-only player, which keeps playing and skips video decode while the screen is
    // off. macOS never does this, so it has nothing to work around.

    private func observeAppLifecycle() {
        #if !os(macOS)
        let center = NotificationCenter.default
        lifecycleObservers = [
            // Synchronously: a Task hop can land after the app is already suspended, which is
            // exactly the pause this detach exists to beat.
            center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
            ) { [weak self] _ in MainActor.assumeIsolated { self?.detachForBackground() } },
            center.addObserver(
                forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main
            ) { [weak self] _ in MainActor.assumeIsolated { self?.reattachPlayer() } }
        ]
        #endif
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

// MARK: - PlayerViewControllerRepresentable

struct PlayerViewControllerRepresentable: View {
    let avPlayer: AVPlayer
    let pipEnabled: Bool
    /// Leaving the app enters PiP when on, and keeps playing audio only when off.
    /// macOS has no auto-PiP (`canStartPictureInPictureAutomaticallyFromInline` is unavailable there).
    let autoPip: Bool
    let onPipChanged: (Bool) -> Void

    var body: some View {
        PlayerLayerHost(
            avPlayer: avPlayer,
            pipEnabled: pipEnabled,
            autoPip: autoPip,
            onPipChanged: onPipChanged
        )
    }
}

#if canImport(UIKit)

private struct PlayerLayerHost: UIViewControllerRepresentable {
    let avPlayer: AVPlayer
    let pipEnabled: Bool
    let autoPip: Bool
    let onPipChanged: (Bool) -> Void

    func makeUIViewController(context: Context) -> AVPlayerLayerViewController {
        let vc = AVPlayerLayerViewController()
        vc.controller.playerLayer.player = avPlayer
        apply(to: vc.controller)
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerLayerViewController, context: Context) {
        apply(to: vc.controller)
    }

    private func apply(to controller: PlayerLayerController) {
        controller.isPipRequested = pipEnabled
        controller.autoPip = autoPip
        controller.onPipChanged = onPipChanged
        controller.applyPipState()
    }
}

final class AVPlayerLayerViewController: UIViewController {
    let controller = PlayerLayerController()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.layer.addSublayer(controller.playerLayer)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        controller.playerLayer.frame = view.bounds
    }
}

#else

private struct PlayerLayerHost: NSViewRepresentable {
    let avPlayer: AVPlayer
    let pipEnabled: Bool
    let autoPip: Bool
    let onPipChanged: (Bool) -> Void

    func makeNSView(context: Context) -> AVPlayerLayerView {
        let view = AVPlayerLayerView()
        view.controller.playerLayer.player = avPlayer
        apply(to: view.controller)
        return view
    }

    func updateNSView(_ view: AVPlayerLayerView, context: Context) {
        apply(to: view.controller)
    }

    private func apply(to controller: PlayerLayerController) {
        controller.isPipRequested = pipEnabled
        controller.autoPip = autoPip
        controller.onPipChanged = onPipChanged
        controller.applyPipState()
    }
}

final class AVPlayerLayerView: NSView {
    let controller = PlayerLayerController()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.addSublayer(controller.playerLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isOpaque: Bool { false }

    /// The SwiftUI gesture overlays stacked on top of the player own every click.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        controller.playerLayer.frame = bounds
    }
}

#endif

// MARK: - SeekAnchor

// Tracks the intended seek target between rapid seeks so relative seeks don't
// re-read avPlayer.currentTime(), which lags behind until a seek completes.
final class SeekAnchor {
    var time: Double?
}
