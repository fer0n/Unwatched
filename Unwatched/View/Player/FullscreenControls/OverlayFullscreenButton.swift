//
//  OverlayFullscreenButton.swift
//  Unwatched
//

import SwiftUI

@Observable class OverlayFullscreenVM {
    @ObservationIgnored var hideControlsTask: (Task<(), Never>)?

    var icon: OverlayIcon = .play
    var show = false {
        didSet {
            Task {
                if show {
                    try? await Task.sleep(s: 0.2)
                    show = false
                }
            }
        }
    }

    func show(_ icon: OverlayIcon) {
        self.icon = icon
        show = true
    }
}

struct OverlayFullscreenButton: View {
    @Environment(PlayerManager.self) var player
    @Binding var overlayVM: OverlayFullscreenVM

    var enabled: Bool
    var landscapeFullscreen: Bool

    var body: some View {
        let touchSize: CGFloat = landscapeFullscreen ? 125 : 90

        Color.white
            .opacity(.leastNonzeroMagnitude)
            .contentShape(Rectangle())
            .frame(width: touchSize, height: touchSize)
            .onTapGesture {
                overlayVM.show(player.isPlaying ? .pause : .play)
                player.handlePlayButton()
            }
            .opacity(enabled ? 1 : 0)
            .overlay {
                Image(systemName: overlayVM.icon.systemName)
                    .resizable()
                    .frame(width: 90, height: 90)
                    .animation(nil, value: overlayVM.show)
                    .fontWeight(.black)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.black, .white)
                    .opacity(overlayVM.show && landscapeFullscreen ? 1 : 0)

                    .scaleEffect(overlayVM.show && landscapeFullscreen ? 1 : 0.7)
                    .animation(.bouncy, value: overlayVM.show)
                    .accessibilityLabel("playPause")

                if player.videoEnded {
                    PlayButton(size: 90)
                        .opacity(enabled && landscapeFullscreen ? 1 : 0)
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
