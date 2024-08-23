//
//  PlayButton.swift
//  Unwatched
//

import SwiftUI

struct CorePlayButton<Content>: View where Content: View {
    @AppStorage(Const.forceYtWatchHistory) var forceYtWatchHistory = false
    @Environment(PlayerManager.self) var player
    @State var hapticToggle: Bool = false

    @State var showHelperPopop = false

    private let contentImage: ((Image, Bool) -> Content)
    private let circle: String
    let enableHaptics: Bool

    init(
        circleVariant: Bool,
        enableHaptics: Bool = false,
        @ViewBuilder content: @escaping (Image, Bool) -> Content = { image, _ in image }
    ) {
        self.circle = circleVariant ? ".circle" : ""
        self.enableHaptics = enableHaptics
        self.contentImage = content
    }

    var body: some View {
        let disabled = forceYtWatchHistory && player.unstarted

        Button {
            if disabled {
                showHelperPopop = true
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
                        : "play\(circle).fill"),
                disabled
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
            player.handleChapterRefresh(forceRefresh: true)
        } label: {
            Label("reloadVideo", systemImage: "arrow.circlepath")
        }
    }
}

struct PlayButton: View {
    var size: Double
    var enableHaptics: Bool = true

    var body: some View {
        CorePlayButton(
            circleVariant: true,
            enableHaptics: enableHaptics
        ) { image, disabled in
            image
                .resizable()
                .frame(width: size, height: size)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.automaticWhite, .automaticBlack)
                .fontWeight(.black)
                .opacity(disabled ? 0.5 : 1)
        }
    }
}

#Preview {
    PlayButton(size: 90)
        .modelContainer(DataController.previewContainer)
        .environment(PlayerManager())
}
