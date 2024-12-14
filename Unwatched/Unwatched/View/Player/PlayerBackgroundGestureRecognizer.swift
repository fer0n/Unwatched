//
//  BackgroundSeekRecognizer.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PlayerBackgroundGestureRecognizer: View {
    @Environment(PlayerManager.self) var player

    @State var hapticToggle: Bool = false
    @State var longPressed: Bool = false

    let minDuration: Double = 0.2
    let maxDistance: Double = 3

    var body: some View {
        HStack(spacing: 0) {
            Color.playerBackground
                .onTapGesture(count: 2) {
                    if player.seekBackward() {
                        hapticToggle.toggle()
                        OverlayFullscreenVM.shared.show(.seekBackward)
                    }
                }
                .onLongPressGesture(minimumDuration: minDuration, maximumDistance: maxDistance) {
                    handleLongPressEnded(slowDown: true)
                } onPressingChanged: { value in
                    handleLongPressChanged(value)
                }

            Color.playerBackground
                .onTapGesture(count: 2) {
                    if player.seekForward() {
                        hapticToggle.toggle()
                        OverlayFullscreenVM.shared.show(.seekForward)
                    }
                }
                .onLongPressGesture(minimumDuration: minDuration, maximumDistance: maxDistance) {
                    handleLongPressEnded(slowDown: false)
                } onPressingChanged: { value in
                    handleLongPressChanged(value)
                }
        }
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
    }

    func handleLongPressEnded(slowDown: Bool) {
        longPressed = true
        if slowDown {
            player.temporarySlowDown()
        } else {
            player.temporarySpeedUp()
        }
    }

    func handleLongPressChanged(_ value: Bool) {
        if !value && longPressed {
            longPressed = false
            player.resetTemporaryPlaybackSpeed()
        }
    }
}
