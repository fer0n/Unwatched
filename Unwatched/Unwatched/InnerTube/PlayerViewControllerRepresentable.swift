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
        }

        return vc
    }

    func updateUIViewController(_ vc: AVPlayerLayerViewController, context: Context) {
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

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        playerLayer.videoGravity = .resizeAspect
        view.layer.addSublayer(playerLayer)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer.frame = view.bounds
    }
}

// MARK: - SeekAnchor

// Tracks the intended seek target between rapid seeks so relative seeks don't
// re-read avPlayer.currentTime(), which lags behind until a seek completes.
final class SeekAnchor {
    var time: Double? = nil
}
#endif
