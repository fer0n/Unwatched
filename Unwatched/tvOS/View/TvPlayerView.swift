//
//  TvPlayerView.swift
//  UnwatchedTV
//

import AVKit
import SwiftData
import SwiftUI
import UnwatchedShared

/// Full-screen in-app playback. Wraps `AVPlayerViewController` so the video gets the system
/// playback experience: transport bar with scrubbing preview, subtitle and audio-track menus,
/// and the remote gestures viewers expect on tvOS.
struct TvPlayerView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    @AppStorage(Const.markAsWatched) var markAsWatched: Bool = false

    @Query(sort: \QueueEntry.order) private var queue: [QueueEntry]

    @State private var viewModel: TvPlayerViewModel?
    /// What's on screen right now: the player can move on to the next queue video without
    /// being dismissed and presented again.
    @State private var video: Video
    @FocusState private var endOverlayFocus: EndOverlayAction?

    var openYouTube: (String?) async -> Bool

    init(video: Video, openYouTube: @escaping (String?) async -> Bool) {
        _video = State(initialValue: video)
        self.openYouTube = openYouTube
    }

    /// Buttons of the overlay a finished video shows.
    private enum EndOverlayAction {
        case watched
        case next
        case restart
        case close
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            content
        }
        .task(id: video.persistentModelID) {
            viewModel?.stop()
            let viewModel = TvPlayerViewModel(video: video, modelContext: modelContext)
            self.viewModel = viewModel
            await viewModel.start()
        }
        .onChange(of: viewModel?.state) { oldState, newState in
            // Only when playback first starts: restarting a finished video shouldn't mark it again.
            if oldState == .loading, newState == .playing, markAsWatched {
                viewModel?.markWatched()
            }
        }
        .onDisappear {
            viewModel?.stop()
        }
    }

    @ViewBuilder
    var content: some View {
        if let viewModel {
            switch viewModel.state {
            case .loading:
                ProgressView()
            case .playing, .ended:
                ZStack {
                    SystemVideoPlayer(
                        player: viewModel.player,
                        // The player controller keeps focus as long as it can take input, which
                        // would leave the overlay's buttons unreachable.
                        isActive: viewModel.state == .playing,
                        speed: viewModel.playbackSpeed,
                        onExit: { dismiss() }
                    )
                    .ignoresSafeArea()

                    if viewModel.state == .ended {
                        endOverlay(viewModel)
                    }
                }
            case .failed(let message):
                failedView(message)
            }
        } else {
            ProgressView()
        }
    }

    @ViewBuilder
    func endOverlay(_ viewModel: TvPlayerViewModel) -> some View {
        ZStack {
            Color.black
                .opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                // Focusing "next" previews what it would play, so the button doesn't have to be
                // taken on faith.
                Text(endOverlayFocus == .next ? (nextVideo?.title ?? video.title) : video.title)
                    .font(.title3)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 900)
                    .animation(.default, value: endOverlayFocus == .next)

                HStack(spacing: 30) {
                    Button("markWatched", systemImage: Const.checkmarkSF) {
                        viewModel.markWatched()
                        dismiss()
                    }
                    .focused($endOverlayFocus, equals: .watched)

                    if nextVideo != nil {
                        Button("nextVideo", systemImage: Const.nextVideoSF) {
                            playNext(viewModel)
                        }
                        .focused($endOverlayFocus, equals: .next)
                    }

                    Button("restartVideo", systemImage: "arrow.counterclockwise") {
                        viewModel.restart()
                    }
                    .focused($endOverlayFocus, equals: .restart)

                    Button("close", systemImage: Const.clearNoFillSF) {
                        dismiss()
                    }
                    .focused($endOverlayFocus, equals: .close)
                }
            }
        }
        .onExitCommand {
            dismiss()
        }
        .task {
            endOverlayFocus = nextVideo == nil ? .watched : .next
        }
    }

    /// The queue video that follows the one playing. The current video is gone from the queue once
    /// it's marked watched, which leaves whatever moved up to the top as the next one.
    private var nextVideo: Video? {
        let videos = queue.compactMap(\.video)
        guard let index = videos.firstIndex(where: { $0.persistentModelID == video.persistentModelID }) else {
            return videos.first
        }
        return videos.dropFirst(index + 1).first
    }

    private func playNext(_ viewModel: TvPlayerViewModel) {
        // Read before marking watched: that drops the current entry and reshuffles the queue.
        guard let next = nextVideo else { return }
        viewModel.markWatched()
        video = next
    }

    @ViewBuilder
    func failedView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: Const.errorSF)
                .font(.title)

            Text("playbackFailed")
                .font(.title3)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 20)

            // The video can still be watched even when no stream could be resolved for it
            // (age-restricted videos, for instance, never resolve).
            Button("playbackModeYouTube") {
                Task {
                    _ = await openYouTube(video.youtubeId)
                    dismiss()
                }
            }
            Button("close") {
                dismiss()
            }
        }
        .frame(maxWidth: 700)
    }
}

// MARK: - SystemVideoPlayer

private struct SystemVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer
    /// While inactive the controller neither shows its transport bar nor takes focus, which hands
    /// both over to whatever is layered on top of it.
    let isActive: Bool
    /// Preselects the speed the app resolved for this video in the player's own speed menu.
    let speed: Double
    let onExit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onExit: onExit)
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        // The Menu button has to be caught here: it never reaches SwiftUI's `onExitCommand`
        // while the player controller holds focus, which would leave no way out of the player.
        let menuPress = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleMenuPress)
        )
        menuPress.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
        controller.view.addGestureRecognizer(menuPress)
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        context.coordinator.onExit = onExit
        if controller.player !== player {
            controller.player = player
            // A new player means a new video: its speed deserves selecting again.
            context.coordinator.didSelectSpeed = false
        }
        controller.showsPlaybackControls = isActive
        controller.view.isUserInteractionEnabled = isActive

        // Selected once per video: after that the choice belongs to the viewer, who can change it
        // in the player's speed menu for as long as the video runs.
        if !context.coordinator.didSelectSpeed {
            context.coordinator.didSelectSpeed = true
            controller.speeds = TvSpeed.selectable(including: speed).map {
                AVPlaybackSpeed(rate: Float($0), localizedName: TvSpeed.label($0))
            }
            if let match = controller.speeds.first(where: { TvSpeed.isSame(Double($0.rate), speed) }) {
                controller.selectSpeed(match)
            }
        }
    }

    final class Coordinator: NSObject {
        var onExit: () -> Void
        var didSelectSpeed = false

        init(onExit: @escaping () -> Void) {
            self.onExit = onExit
        }

        @objc func handleMenuPress() {
            onExit()
        }
    }
}

#Preview {
    TvPlayerView(video: Video.getDummy(), openYouTube: { _ in false })
        .modelContainer(DataProvider.previewContainerFilled)
}
