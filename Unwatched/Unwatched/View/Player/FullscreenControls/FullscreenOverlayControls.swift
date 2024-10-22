//
//  OverlayFullscreenButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

@Observable class OverlayFullscreenVM {
    @ObservationIgnored var hideControlsTask: (Task<(), Never>)?

    var icon: OverlayIcon = .play
    var show = false {
        didSet {
            if !show {
                return
            }
            hideControlsTask?.cancel()
            hideControlsTask = Task {
                try? await Task.sleep(s: 0.2)
                show = false
            }
        }
    }

    func show(_ icon: OverlayIcon) {
        self.icon = icon
        show = true
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
                .frame(width: 90, height: 90)
                .animation(nil, value: overlayVM.show)
                .fontWeight(.black)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.black, .white)
                .opacity(overlayVM.show && show ? 1 : 0)
                .scaleEffect(overlayVM.show && show ? 1 : 0.7)
                .animation(.bouncy, value: overlayVM.show)
                .accessibilityLabel("playPause")
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
}

enum OverlayIcon {
    case play
    case pause
    case next
    case previous

    var systemName: String {
        switch self {
        case .play: return "play.circle.fill"
        case .pause: return "pause.circle.fill"
        case .next: return "forward.end.circle.fill"
        case .previous: return "backward.end.circle.fill"
        }
    }
}

#Preview {
    let player = PlayerManager()
    player.videoEnded = true

    return FullscreenOverlayControls(
        overlayVM: .constant(OverlayFullscreenVM()),
        enabled: true,
        show: true,
        markVideoWatched: {_, _ in }
    )
    .environment(player)
    .modelContainer(DataController.previewContainerFilled)
}
