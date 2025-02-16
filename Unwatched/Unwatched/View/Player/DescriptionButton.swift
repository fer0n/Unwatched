//
//  DescriptionButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct DescriptionButton: View {
    @Environment(PlayerManager.self) var player
    @Environment(NavigationManager.self) var navManager
    @Environment(\.colorScheme) var colorScheme
    @Binding var show: Bool

    var body: some View {
        Button {
            show = true
        } label: {
            Image(systemName: Const.videoDescriptionSF)
                .symbolRenderingMode(.monochrome)
                .playerToggleModifier(isOn: show, isSmall: true)
        }
        .popover(isPresented: $show) {
            if let video = player.video {
                ChapterDescriptionView(video: video)
                    .environment(\.colorScheme, colorScheme)
                    .environment(player)
                    .environment(navManager)
            }
        }
        .sensoryFeedback(Const.sensoryFeedback, trigger: show)
    }
}
