//
//  PlayButton.swift
//  Unwatched
//

import SwiftUI
import OSLog
import UnwatchedShared

struct CorePlayButton<Content>: View where Content: View {
    @Environment(PlayerManager.self) var player
    @State var hapticToggle: Bool = false

    private let contentImage: ((Image) -> Content)
    private let circle: String
    let enableHaptics: Bool
    let enableHelperPopup: Bool

    init(
        circleVariant: Bool,
        enableHaptics: Bool = false,
        enableHelperPopup: Bool = true,
        @ViewBuilder content: @escaping (Image) -> Content = { $0 }
    ) {
        self.circle = circleVariant ? ".circle" : ""
        self.enableHaptics = enableHaptics
        self.enableHelperPopup = enableHelperPopup
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
        .keyboardShortcut(.space, modifiers: [])
        .accessibilityLabel(player.isPlaying ? "pause" : "play")
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
        .contextMenu {
            PlayButtonContextMenu()
        }
    }
}

struct PlayButtonContextMenu: View {
    @Environment(PlayerManager.self) var player

    var body: some View {
        Button {
            player.restartVideo()
        } label: {
            Label("restartVideo", systemImage: "restart")
        }
        Divider()
        Button {
            player.embeddingDisabled = false
            player.handleHotSwap()
            PlayerManager.reloadPlayer()
            player.handleChapterRefresh(forceRefresh: true)
        } label: {
            Label("reloadVideo", systemImage: Const.reloadSF)
        }
    }
}

struct PlayButton: View {
    var size: Double
    var enableHaptics: Bool = true
    var enableHelper: Bool = true

    var body: some View {
        CorePlayButton(
            circleVariant: true,
            enableHaptics: enableHaptics,
            enableHelperPopup: enableHelper
        ) { image in
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
