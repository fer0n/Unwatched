#if !os(macOS)
import AVKit
import SwiftUI

// MARK: - PlayerViewControllerRepresentable

struct PlayerViewControllerRepresentable: UIViewControllerRepresentable {
    let avPlayer: AVPlayer
    let pipEnabled: Bool
    let onPipChanged: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPipChanged: onPipChanged)
    }

    func makeUIViewController(context: Context) -> AVPlayerLayerViewController {
        let vc = AVPlayerLayerViewController()
        vc.playerLayer.player = avPlayer

        if AVPictureInPictureController.isPictureInPictureSupported() {
            let pip = AVPictureInPictureController(playerLayer: vc.playerLayer)
            pip?.canStartPictureInPictureAutomaticallyFromInline = true
            pip?.delegate = context.coordinator
            context.coordinator.pipController = pip
            vc.pipController = pip
        }

        return vc
    }

    func updateUIViewController(_ vc: AVPlayerLayerViewController, context: Context) {
        vc.isPipRequested = pipEnabled
        guard let pip = context.coordinator.pipController else { return }
        if pipEnabled && !pip.isPictureInPictureActive && pip.isPictureInPicturePossible {
            pip.startPictureInPicture()
        } else if !pipEnabled && pip.isPictureInPictureActive {
            pip.stopPictureInPicture()
        }
    }

    class Coordinator: NSObject, AVPictureInPictureControllerDelegate {
        let onPipChanged: (Bool) -> Void
        var pipController: AVPictureInPictureController?

        init(onPipChanged: @escaping (Bool) -> Void) {
            self.onPipChanged = onPipChanged
        }

        func pictureInPictureControllerWillStartPictureInPicture(_ pip: AVPictureInPictureController) {
            onPipChanged(true)
        }

        func pictureInPictureControllerWillStopPictureInPicture(_ pip: AVPictureInPictureController) {
            onPipChanged(false)
        }
    }
}

// MARK: - AVPlayerLayerViewController

final class AVPlayerLayerViewController: UIViewController {
    let playerLayer = AVPlayerLayer()

    /// Set by the representable; both are consulted before backgrounding so PiP keeps its layer.
    weak var pipController: AVPictureInPictureController?
    var isPipRequested = false

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

    // MARK: - Background detach
    //
    // iOS pauses an AVPlayer that still renders into a layer as soon as the app is
    // backgrounded — screen lock included — no matter what the `audio` background mode
    // says. Detaching the layer leaves an audio-only player, which keeps playing, and
    // skips video decode entirely while the screen is off.

    private func observeAppLifecycle() {
        let center = NotificationCenter.default
        lifecycleObservers = [
            center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
            ) { [weak self] _ in self?.detachForBackground() },
            center.addObserver(
                forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main
            ) { [weak self] _ in self?.reattachForForeground() }
        ]
    }

    private func detachForBackground() {
        // PiP renders from this layer; detaching would kill the PiP window.
        guard !isPipRequested, pipController?.isPictureInPictureActive != true else { return }
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
