//
//  PlayButton.swift
//  Unwatched
//

import SwiftUI

struct CorePlayButton<Content>: View where Content: View {
    @Environment(PlayerManager.self) var player
    @State var hapticToggle: Bool = false

    private let contentImage: ((Image) -> Content)
    private let circle: String
    let enableHaptics: Bool

    init(
        circleVariant: Bool,
        enableHaptics: Bool = false,
        @ViewBuilder content: @escaping (Image) -> Content = { $0 }
    ) {
        self.circle = circleVariant ? ".circle" : ""
        self.enableHaptics = enableHaptics
        self.contentImage = content
    }

    var body: some View {
        Button {
            player.handlePlayButton()
            if enableHaptics {
                hapticToggle.toggle()
            }
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
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
        .contextMenu {
            PlayButtonContextMenu()
        }
        .keyboardShortcut(.space, modifiers: [])
    }
}

struct PlayButtonContextMenu: View {
    @AppStorage(Const.reloadVideoId) var reloadVideoId: String = ""
    @Environment(PlayerManager.self) var player

    var body: some View {
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

struct PlayButton: View {
    var size: Double
    var enableHaptics: Bool = true

    var body: some View {
        CorePlayButton(circleVariant: true, enableHaptics: enableHaptics) { image in
            image
                .resizable()
                .frame(width: size, height: size)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.automaticWhite, .automaticBlack)
                .fontWeight(.black)
        }

    }
}

#Preview {
    PlayButton(size: 90)
        .modelContainer(DataController.previewContainer)
        .environment(PlayerManager())
}
