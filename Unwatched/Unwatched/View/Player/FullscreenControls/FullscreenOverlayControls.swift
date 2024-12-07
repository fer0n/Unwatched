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
            image
                .resizable()
                .animation(nil, value: overlayVM.show)
                .frame(width: 90, height: 90)
                .phaseAnimator([0, 1, 0], trigger: overlayVM.show) { view, phase in
                    view
                        .scaleEffect(phase == 1 ? 1 : 0.75)
                        .opacity(phase == 1 ? 0.8 : 0)
                } animation: { _ in
                    .easeInOut(duration: 0.2)
                }
                .fontWeight(overlayVM.icon.fontWeight)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.black, .white)
                .allowsHitTesting(false)

            if player.videoEnded {
                HStack {
                    WatchedButton(markVideoWatched: markVideoWatched)
                        .frame(maxWidth: .infinity)

                    PlayButton(size: 90)

                    NextVideoButton(markVideoWatched: markVideoWatched)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: 500)
                .padding(.horizontal, 10)
                .opacity(enabled && show ? 1 : 0)
                .animation(.default, value: show)
            }
        }
    }

    var image: Image {
        if let systemName = overlayVM.icon.systemName {
            return Image(systemName: systemName)
        }
        if let customImageName = overlayVM.icon.customImageName {
            return Image(customImageName)
        }
        return Image(systemName: "circle.fill")
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

    var systemName: String? {
        switch self {
        case .play: return "play.circle.fill"
        case .pause: return "pause.circle.fill"
        case .next: return "forward.end.circle.fill"
        case .previous: return "backward.end.circle.fill"
        case .watched: return "checkmark.circle.fill"
        case .nextVideo: return "forward.circle.fill"
        default: return nil
        }
    }

    var customImageName: String? {
        switch self {
        case .seekForward: return "custom.arrow.trianglehead.clockwise.circle.fill"
        case .seekBackward: return "custom.arrow.trianglehead.counterclockwise.circle.fill"
        default: return nil
        }
    }

    var fontWeight: Font.Weight {
        switch self {
        case .play, .pause: return .black
        default: return .regular
        }
    }
}

#Preview {
    let player = PlayerManager()
    player.videoEnded = false

    return FullscreenOverlayControls(
        overlayVM: .constant(OverlayFullscreenVM()),
        enabled: true,
        show: true,
        markVideoWatched: {_, _ in }
    )
    .environment(player)
    .modelContainer(DataProvider.previewContainerFilled)
}
