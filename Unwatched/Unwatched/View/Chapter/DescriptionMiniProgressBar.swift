//
//  DescriptionMiniProgressBar.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct DescriptionMiniProgressBar: View {
    @Environment(PlayerManager.self) var player
    @Environment(NavigationManager.self) var navManager

    var height: CGFloat?
    var inlineTime = false

    var body: some View {
        if !player.embeddingDisabled {
            PlayerScrubber(
                height: height,
                inlineTime: inlineTime,
                translucent: true
            )
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    DescriptionMiniProgressBar()
        .environment(NavigationManager())
        .environment(PlayerManager.getDummy())
        .modelContainer(DataProvider.previewContainerFilled)
}
