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
    var show = false
    private var hideTask: Task<Void, Never>?

    init() {}

    func show(_ icon: OverlayIcon) {
        // If showing the same icon, cancel the hide task to keep it visible
        if self.icon == icon && show {
            hideTask?.cancel()
            hideTask = nil
            scheduleHide()
            return
        }

        self.icon = icon
        show = true
        scheduleHide()
    }

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            show = false
        }
    }
}

struct FullscreenOverlayControls: View {
    @Environment(PlayerManager.self) var player
    @Binding var overlayVM: OverlayFullscreenVM

    var enabled: Bool
    var show: Bool

    var body: some View {
        ZStack {
            Image(systemName: overlayVM.icon.systemName)
                .resizable()
                .animation(nil, value: overlayVM.show)
                .frame(width: 80, height: 80)
                .scaleEffect(overlayVM.show ? 1 : 0.75)
                .backgroundTransparentEffect(fallback: .thinMaterial)
                .opacity(overlayVM.show ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: overlayVM.show)
                .fontWeight(overlayVM.icon.fontWeight)
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.white.opacity(0.7), .clear)
                .allowsHitTesting(false)

            HStack {
                WatchedButton(
                    backgroundColor: .clear
                )
                .backgroundTransparentEffect(fallback: .ultraThinMaterial)
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
                        .foregroundStyle(.primary, .clear)
                        .fontWeight(.black)
                }
                .backgroundTransparentEffect(fallback: .regularMaterial)

                NextVideoButton(
                    backgroundColor: .clear
                )
                .backgroundTransparentEffect(fallback: .ultraThinMaterial)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: 500)
            .padding(.horizontal, 10)
            .opacity(player.videoEnded && enabled && show ? 1 : 0)
            .allowsHitTesting(player.videoEnded && enabled && show)
            .animation(.default, value: show)
        }
    }
}

extension View {
    func backgroundTransparentEffect(fallback: Material) -> some View {
        self
            #if os(visionOS)
            .fallbackBackground(fallback)
        #else
        .apply {
        if #available(iOS 26, macOS 26, *) {
        $0
        .contentShape(Circle())
        .glassEffect()
        } else {
        $0.fallbackBackground(fallback)
        }
        }
        #endif
    }

    private func fallbackBackground(_ fallback: Material) -> some View {
        self
            .background(fallback)
            .clipShape(Circle())
    }
}

enum OverlayIcon: Equatable {
    case play
    case pause
    case next
    case previous
    case seekForward
    case seekBackward
    case watched
    case nextVideo
    case queued
    case speedUp
    case slowDown
    case regularSpeed

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
        case .speedUp: return "waveform.circle.fill"
        case .slowDown: return "waveform.circle.fill"
        case .regularSpeed: return "slash.circle.fill"
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
            )
    }
    .environment(\.colorScheme, .dark)
    .environment(player)
    .modelContainer(DataProvider.previewContainerFilled)
}
