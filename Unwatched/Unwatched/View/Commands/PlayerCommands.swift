//
//  PlayerCommands.swift
//  Unwatched
//

import UnwatchedShared
import SwiftUI

struct PlayerCommands: Commands {
    // redraws the seek titles when the duration changes
    @AppStorage(Const.doubleTapSeekDuration) var seekDuration: Double?

    var body: some Commands {
        CommandMenu("playback") {
            Section {
                PlayerShortcut.playPause.render()
                PlayerShortcut.playPause.render(isAlt: true)

                PlayerShortcut.seekBackwardArrow.render()
                PlayerShortcut.seekForwardArrow.render()

                PlayerShortcut.seekBackwardCustom.render()
                PlayerShortcut.seekForwardCustom.render()

                PlayerShortcut.previousChapter.render(isAlt: true)
                PlayerShortcut.nextChapter.render(isAlt: true)

                PlayerShortcut.previousChapter.render()
                PlayerShortcut.nextChapter.render()
            }

            Section("playbackSpeed") {
                PlayerShortcut.speedUp.render()
                PlayerShortcut.slowDown.render()

                PlayerShortcut.speedUp.render(isAlt: true)
                PlayerShortcut.slowDown.render(isAlt: true)

                PlayerShortcut.temporarySlowDown.render()
                PlayerShortcut.temporarySpeedUp.render()
            }
        }

        CommandMenu("video") {
            PlayerShortcut.markWatched.render()
            PlayerShortcut.nextVideo.render()

            Section {
                PlayerShortcut.openInAppBrowser.render()
                PlayerShortcut.openInExternalBrowser.render()
            }
        }
    }
}
