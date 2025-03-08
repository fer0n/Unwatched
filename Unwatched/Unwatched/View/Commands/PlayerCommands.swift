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

            if Device.isMac {
                Button("seekBackward") {
                    seekBackward()
                }
                .keyboardShortcut(.leftArrow, modifiers: [])

                Button("seekForward") {
                    seekForward()
                }
                .keyboardShortcut(.rightArrow, modifiers: [])

                Button("previousChapter") {
                    goToPreviousChapter()
                }
                .keyboardShortcut(.leftArrow)

                Button("nextChapter") {
                    goToNextChapter()
                }
                .keyboardShortcut(.rightArrow)

                Divider()
            }

            Button("playPause") {
                player.handlePlayButton()
            }
            .keyboardShortcut("k", modifiers: [])

            // workaround: same commands without arrow keys (for iPad, arrow keys don't work there)
            Button("seekBackward") {
                seekBackward()
            }
            .keyboardShortcut("j", modifiers: [])

            Button("seekForward") {
                seekForward()
            }
            .keyboardShortcut("l", modifiers: [])

            Button("previousChapter") {
                goToPreviousChapter()
            }
            .keyboardShortcut("j")

            Button("nextChapter") {
                goToNextChapter()
            }
            .keyboardShortcut("l")

            Divider()

            #if os(iOS)
            HideControlsButton(textOnly: true, enableEscapeButton: false)
                .keyboardShortcut("f", modifiers: [])
            #endif

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

    func seekForward() {
        if player.seekForward() {
            OverlayFullscreenVM.shared.show(.seekForward)
        }
    }

    func seekBackward() {
        if player.seekBackward() {
            OverlayFullscreenVM.shared.show(.seekBackward)
        }
    }

    func goToPreviousChapter() {
        if player.goToPreviousChapter() {
            OverlayFullscreenVM.shared.show(.previous)
        }
    }

    func goToNextChapter() {
        if player.goToNextChapter() {
            OverlayFullscreenVM.shared.show(.next)
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
