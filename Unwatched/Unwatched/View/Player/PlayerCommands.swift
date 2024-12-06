//
//  PlayerCommands.swift
//  Unwatched
//

import UnwatchedShared
import SwiftUI

struct PlayerCommands: Commands {
    @Binding var player: PlayerManager

    var body: some Commands {
        CommandMenu("playerMenu") {
            Button("playPause") {
                player.handlePlayButton()
            }
            .keyboardShortcut(.space, modifiers: [])

            Button("seekForward") {
                if player.seekForward() {
                    OverlayFullscreenVM.shared.show(.seekForward)
                }
            }
            .keyboardShortcut(.rightArrow, modifiers: [])

            Button("seekBackward") {
                if player.seekBackward() {
                    OverlayFullscreenVM.shared.show(.seekBackward)
                }
            }
            .keyboardShortcut(.leftArrow, modifiers: [])

            Button("previousChapter") {
                if player.goToPreviousChapter() {
                    OverlayFullscreenVM.shared.show(.previous)
                }
            }
            .keyboardShortcut(.leftArrow)

            Button("nextChapter") {
                if player.goToNextChapter() {
                    OverlayFullscreenVM.shared.show(.next)
                }
            }
            .keyboardShortcut(.rightArrow)

            Divider()

            HideControlsButton(textOnly: true, enableEscapeButton: false)
                .keyboardShortcut("f", modifiers: [])

            Button("toggleTemporarySpeed") {
                player.toggleTemporaryPlaybackSpeed()
            }
            .keyboardShortcut("s", modifiers: [])

            Divider()

            Button("markWatched", systemImage: "checkmark") {
                markVideoWatched()
                OverlayFullscreenVM.shared.show(.watched)
            }
            .keyboardShortcut("w", modifiers: [.shift])

            Button("nextVideo") {
                markVideoWatched(playNext: true)
                OverlayFullscreenVM.shared.show(.nextVideo)
            }
            .keyboardShortcut("n", modifiers: [.shift])
        }
    }

    func markVideoWatched(playNext: Bool = false) {
        if let video = player.video {
            let context = DataProvider.newContext()
            VideoService.setVideoWatched(video, modelContext: context)
            player.autoSetNextVideo(playNext ? .userInteraction : .nextUp, context)

            _ = VideoService.setVideoWatchedAsync(video.id)
            try? context.save()
        }
    }
}
