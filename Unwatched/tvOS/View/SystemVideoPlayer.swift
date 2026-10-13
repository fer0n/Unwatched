//
//  SystemVideoPlayer.swift
//  UnwatchedTV
//

import AVKit
import SwiftUI
import UnwatchedShared

struct SystemVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    let isActive: Bool
    let speed: Double
    let artworkUrl: URL?
    let onExit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onExit: onExit)
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        // Menu never reaches `onExitCommand` while the controller has focus
        let menuPress = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleMenuPress)
        )
        menuPress.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
        controller.view.addGestureRecognizer(menuPress)
        if let overlay = controller.contentOverlayView {
            let artwork = context.coordinator.artwork
            controller.addChild(artwork)
            artwork.view.backgroundColor = .clear
            artwork.view.frame = overlay.bounds
            artwork.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            overlay.addSubview(artwork.view)
            artwork.didMove(toParent: controller)
        }
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        context.coordinator.onExit = onExit
        context.coordinator.artwork.rootView = EpisodeArtwork(url: artworkUrl)
        if controller.player !== player {
            controller.player = player
            context.coordinator.didSelectSpeed = false
        }
        controller.showsPlaybackControls = isActive
        controller.view.isUserInteractionEnabled = isActive
        if !context.coordinator.didSelectSpeed {
            context.coordinator.didSelectSpeed = true
            controller.speeds = SpeedHelper.selectable(including: speed).map {
                AVPlaybackSpeed(rate: Float($0), localizedName: SpeedHelper.label($0))
            }
            if let match = controller.speeds.first(where: { SpeedHelper.isSame(Double($0.rate), speed) }) {
                controller.selectSpeed(match)
            }
        }
    }

    final class Coordinator: NSObject {
        var onExit: () -> Void
        var didSelectSpeed = false
        fileprivate let artwork = UIHostingController(rootView: EpisodeArtwork(url: nil))

        init(onExit: @escaping () -> Void) {
            self.onExit = onExit
        }

        @objc func handleMenuPress() {
            onExit()
        }
    }
}

private struct EpisodeArtwork: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 35))
        } placeholder: {
            Color.clear
        }
        .padding(150)
    }
}
