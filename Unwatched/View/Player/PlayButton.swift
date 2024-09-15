//
//  PlayButton.swift
//  Unwatched
//

import SwiftUI
import OSLog

struct CorePlayButton<Content>: View where Content: View {
    @Environment(PlayerManager.self) var player
    @State var hapticToggle: Bool = false

    @State var showHelperPopop = false

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
            if player.playDisabled {
                if enableHelperPopup {
                    showHelperPopop = true
                }
                Logger.log.info("Play button is disabled (forceYtWatchHistory)")
                return
            }
            player.handlePlayButton()
            if enableHaptics {
                hapticToggle.toggle()
            }
        } label: {
            contentImage(
                Image(systemName: player.isPlaying && !player.videoEnded
                        ? "pause\(circle).fill"
                        : player.playDisabled
                        ? "slash.circle.fill"
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
        .popover(isPresented: $showHelperPopop) {
            VStack {
                Spacer()
                    .frame(height: 25)
                Text("playButtonDisabledDueToForceHistory")
                    .padding()
                Spacer()
                    .frame(height: 25)
            }
            .fixedSize(horizontal: false, vertical: true)
            .font(.body)
            .fontWeight(.regular)
            .presentationCompactAdaptation(.popover)
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
        .disabled(player.playDisabled)

        Button {
            player.handleHotSwap()
            PlayerManager.reloadPlayer()
            player.handleChapterRefresh(forceRefresh: true)
        } label: {
            Label("reloadVideo", systemImage: "arrow.circlepath")
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
