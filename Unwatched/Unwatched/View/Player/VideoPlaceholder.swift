//
//  VideoPlaceholder.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct VideoPlaceholder: View {
    @Environment(PlayerManager.self) var player

    var autoHideVM: AutoHideVM
    var fullscreenControlsSetting: FullscreenControls
    let landscapeFullscreen: Bool

    var body: some View {
        Rectangle()
            .fill(landscapeFullscreen ? .black : Color.playerBackgroundColor)
            .aspectRatio(player.videoAspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .background(backgroundTapRecognizer)
            .animation(.default, value: player.videoAspectRatio)
            .edgesIgnoringSafeArea(.all)
    }

    var backgroundTapRecognizer: some View {
        Color.black
            .onTapGesture {
                autoHideVM.setShowControls()
            }
            .disabled(fullscreenControlsSetting != .autoHide)
    }
}
