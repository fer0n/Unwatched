//
//  PlayButton.swift
//  Unwatched
//

import SwiftUI

struct PlayButton: View {
    @Environment(PlayerManager.self) var player
    @State var hapticToggle: Bool = false

    var size: Double

    var body: some View {
        Button {
            player.handlePlayButton()
            hapticToggle.toggle()
        } label: {
            Image(systemName: player.isPlaying && !player.videoEnded
                    ? "pause.circle.fill"
                    : "play.circle.fill")
                .resizable()
                .frame(width: size, height: size)
                .rotationEffect(.degrees(player.videoEnded
                                            ? 180
                                            : 0)
                )
                .accentColor(.myAccentColor)
                .contentTransition(.symbolEffect(.replace, options: .speed(7)))
        }
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
    }
}

#Preview {
    PlayButton(size: 90)
        .modelContainer(DataController.previewContainer)
        .environment(PlayerManager())
}
