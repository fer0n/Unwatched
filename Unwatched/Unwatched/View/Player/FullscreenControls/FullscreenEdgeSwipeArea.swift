//
//  FullscreenEdgeSwipeArea.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// The letterbox bar and safe area strip next to the video: no other view has a gesture there.
struct FullscreenEdgeSwipeArea: View {
    @Environment(PlayerManager.self) var player

    @Binding var autoHideVM: AutoHideVM

    var showLeft: Bool

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                if !showLeft {
                    Spacer(minLength: 0)
                }

                Color.clear
                    .frame(width: width(in: geometry.size))
                    .contentShape(Rectangle())
                    .descriptionEdgeSwipe(
                        autoHideVM: $autoHideVM,
                        side: PlayerEdgeSwipe.Side(showLeft: showLeft),
                        minimumDistance: PlayerEdgeSwipe.minimumDistance
                    )
                    .onTapGesture {
                        autoHideVM.setShowControls()
                    }

                if showLeft {
                    Spacer(minLength: 0)
                }
            }
            .environment(\.layoutDirection, .leftToRight)
        }
        .ignoresSafeArea()
    }

    /// The bar next to the video, extended by `videoInset` to meet the video's own edge zone.
    private func width(in size: CGSize) -> CGFloat {
        let videoWidth = min(size.width, size.height * player.videoAspectRatio)
        return max(0, (size.width - videoWidth) / 2) + PlayerEdgeSwipe.videoInset
    }
}

#Preview {
    FullscreenEdgeSwipeArea(autoHideVM: .constant(AutoHideVM()), showLeft: false)
        .environment(PlayerManager())
}
