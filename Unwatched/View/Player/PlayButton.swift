//
//  PlayButton.swift
//  Unwatched
//

import SwiftUI

struct CorePlayButton<Content>: View where Content: View {
    @AppStorage(Const.reloadVideoId) var reloadVideoId: String = ""
    @Environment(PlayerManager.self) var player
    @State var hapticToggle: Bool = false

    private let contentImage: ((Image) -> Content)
    var circleVariant = true

    init(
        circleVariant: Bool,
        @ViewBuilder content: @escaping (Image) -> Content = { $0 }
    ) {
        self.circleVariant = circleVariant
        self.contentImage = content
    }

    var body: some View {
        let circle = circleVariant ? ".circle" : ""

        Button {
            player.handlePlayButton()
            hapticToggle.toggle()
        } label: {
            contentImage(
                Image(systemName: player.isPlaying && !player.videoEnded
                        ? "pause\(circle).fill"
                        : "play\(circle).fill")
            )
            .rotationEffect(.degrees(player.videoEnded
                                        ? 180
                                        : 0)
            )
            .foregroundStyle(Color.neutralAccentColor)
            .contentTransition(.symbolEffect(.replace, options: .speed(7)))
        }
        .fontWeight(.black)
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
        .contextMenu {
            Button {
                player.restartVideo()
            } label: {
                Label("restartVideo", systemImage: "restart")
            }
            Button {
                player.handleHotSwap()
                reloadVideoId = UUID().uuidString
            } label: {
                Label("reloadVideo", systemImage: "arrow.circlepath")
            }
        }
    }
}

struct PlayButton: View {
    @Environment(PlayerManager.self) var player
    @State var hapticToggle: Bool = false

    var size: Double

    var body: some View {
        CorePlayButton(circleVariant: true) { image in
            image
                .resizable()
                .frame(width: size, height: size)
        }

    }
}

#Preview {
    PlayButton(size: 90)
        .modelContainer(DataController.previewContainer)
        .environment(PlayerManager())
}
