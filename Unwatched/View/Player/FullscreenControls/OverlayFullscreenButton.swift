//
//  OverlayFullscreenButton.swift
//  Unwatched
//

import SwiftUI

struct OverlayFullscreenButton: View {
    @Environment(PlayerManager.self) var player
    @State private var showPause = false
    @State private var show = false

    var enabled: Bool
    var landscapeFullscreen: Bool

    var body: some View {
        let touchSize: CGFloat = landscapeFullscreen ? 125 : 90

        Color.white
            .opacity(.leastNonzeroMagnitude)
            .contentShape(Rectangle())
            .frame(width: touchSize, height: touchSize)
            .onTapGesture {
                showPause = player.isPlaying
                show = true
                player.handlePlayButton()
            }
            .opacity(enabled ? 1 : 0)
            .overlay {
                Image(systemName: showPause ? "pause.circle.fill" : "play.circle.fill" )
                    .resizable()
                    .frame(width: 90, height: 90)
                    .animation(nil, value: show)
                    .fontWeight(.black)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.black, .white)
                    .opacity(show && landscapeFullscreen ? 1 : 0)
                    .task(id: show) {
                        if show {
                            try? await Task.sleep(s: 0.2)
                            show = false
                        }
                    }
                    .scaleEffect(show && landscapeFullscreen ? 1 : 0.7)
                    .animation(.bouncy, value: show)
                    .accessibilityLabel("playPause")

                if player.videoEnded {
                    PlayButton(size: 90)
                        .opacity(enabled && landscapeFullscreen ? 1 : 0)
                }
            }
    }
}
