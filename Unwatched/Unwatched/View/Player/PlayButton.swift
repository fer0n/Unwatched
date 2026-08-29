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
        .contentTransition(.symbolEffect(.replace.magic(fallback: .replace), options: .speed(7)))
        .buttonWithMenu(
            accessibilityLabel: player.isPlaying ? String(localized: "pause") : String(localized: "play"),
            groups: enableHelperPopup ? menuGroups : [],
            onTap: handlePress
        )
        .background {
            // the tap is a gesture on the hosted view now, so the space bar needs its own button
            Button(action: handlePress) { }
                .keyboardShortcut(.space, modifiers: [])
                .opacity(0)
        }
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
    }

    var menuGroups: [MenuActionGroup] {
        [
            MenuActionGroup([
                MenuAction(String(localized: "restartVideo"), systemImage: "restart") {
                    player.restartVideo()
                }
            ]),
            MenuActionGroup([
                MenuAction(String(localized: "reloadPlayer"), systemImage: Const.reloadSF) {
                    ReloadPlayerButton.reload(player)
                }
            ])
        ]
    }

    func handlePress() {
        player.handlePlayButton()
        Signal.log("Player.PlayPause", throttle: .daily)
        if enableHaptics {
            hapticToggle.toggle()
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
        #if !os(visionOS)
        .playerControlBackground(in: Circle())
        #endif
    }
}

struct PlayerControlsPlayButton: View {
    @ScaledMetric var size: CGFloat

    init(size: Size) {
        let absoluteSize = PlayerControlsPlayButton.playButtonSize(size)
        self._size = ScaledMetric(wrappedValue: absoluteSize)
    }

    var body: some View {
        PlayButton(size: size)
            .fontWeight(.black)
    }

    static func playButtonSize(_ size: Size) -> CGFloat {
        switch size {
        case .small:
            return 45
        case .medium:
            return 80
        case .large:
            return 90
        }
    }

    enum Size {
        case small
        case medium
        case large
    }
}

struct PlayButtonSpacer: View {
    var padding: CGFloat = 0
    @ScaledMetric var size: CGFloat

    init(padding: CGFloat, size: PlayerControlsPlayButton.Size) {
        self.padding = padding
        let absoluteSize = PlayerControlsPlayButton.playButtonSize(size)
        self._size = ScaledMetric(wrappedValue: absoluteSize)
    }

    var body: some View {
        Spacer()
            .frame(minHeight: 0, maxHeight: max(0, size + padding))
    }
}

#Preview {
    PlayButton(size: 90)
        .modelContainer(DataProvider.previewContainer)
        .environment(PlayerManager())
}
