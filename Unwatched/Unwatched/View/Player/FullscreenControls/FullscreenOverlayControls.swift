//
//  OverlayFullscreenButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

@MainActor
@Observable class OverlayFullscreenVM {
    static let shared: OverlayFullscreenVM = {
        OverlayFullscreenVM()
    }()

    var icon: OverlayIcon = .play

    @MainActor
    var show = false

    init() {}

    @MainActor
    func show(_ icon: OverlayIcon) {
        self.icon = icon
        show.toggle()
    }
}

struct FullscreenOverlayControls: View {
    @Environment(PlayerManager.self) var player
    @Binding var overlayVM: OverlayFullscreenVM

    var enabled: Bool
    var show: Bool
    var markVideoWatched: (_ showMenu: Bool, _ source: VideoSource) -> Void

    var body: some View {
        ZStack {
            Image(systemName: overlayVM.icon.systemName)
                .resizable()
                .animation(nil, value: overlayVM.show)
                .frame(width: 80, height: 80)
                .phaseAnimator([0, 1, 0], trigger: overlayVM.show) { view, phase in
                    view
                        .scaleEffect(phase == 1 ? 1 : 0.75)
                        .opacity(phase == 1 ? 1 : 0)
                } animation: { _ in
                    .easeInOut(duration: 0.15)
                }
                .fontWeight(overlayVM.icon.fontWeight)
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.white.opacity(0.7), .ultraThinMaterial)
                .allowsHitTesting(false)

            if player.videoEnded {
                HStack {
                    WatchedButton(
                        markVideoWatched: markVideoWatched,
                        indicateWatched: false,
                        material: .ultraThinMaterial
                    )
                    .frame(maxWidth: .infinity)

                    CorePlayButton(
                        circleVariant: true,
                        enableHaptics: true,
                        enableHelperPopup: false
                    ) { image in
                        image
                            .resizable()
                            .frame(width: 90, height: 90)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.automaticBlack, .regularMaterial)
                            .fontWeight(.black)
                    }

                    NextVideoButton(
                        markVideoWatched: markVideoWatched,
                        material: .ultraThinMaterial
                    )
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: 500)
                .padding(.horizontal, 10)
                .opacity(enabled && show ? 0.98 : 0)
                .animation(.default, value: show)
            }
        }
    }
}

enum OverlayIcon {
    case play
    case pause
    case next
    case previous
    case seekForward
    case seekBackward
    case watched
    case nextVideo
    case queued

    var systemName: String {
        switch self {
        case .play: return "play.circle.fill"
        case .pause: return "pause.circle.fill"
        case .next: return "chevron.right.circle.fill"
        case .previous: return "chevron.left.circle.fill"
        case .watched: return "checkmark.circle.fill"
        case .nextVideo: return "\(Const.nextVideoSF).circle.fill"
        case .seekBackward: return "arrow.counterclockwise.circle.fill"
        case .seekForward: return "arrow.clockwise.circle.fill"
        case .queued: return "arrow.uturn.right.circle.fill"
        }
    }

    var fontWeight: Font.Weight {
        switch self {
        case .play, .pause: return .black
        case .next, .previous: return .bold
        default: return .regular
        }
    }
}

#Preview {
    @Previewable @State var overlayVM = OverlayFullscreenVM()

    let player = PlayerManager()
    player.videoEnded = true

    return ZStack {
        Color.gray
        Color.white
            .opacity(0.9)
            .onTapGesture {
                overlayVM.show(.play)
            }

        FullscreenOverlayControls(
            overlayVM: $overlayVM,
            enabled: true,
            show: true,
            markVideoWatched: {_, _ in }
        )
    }
    .environment(\.colorScheme, .dark)
    .environment(player)
    .modelContainer(DataProvider.previewContainerFilled)
}
