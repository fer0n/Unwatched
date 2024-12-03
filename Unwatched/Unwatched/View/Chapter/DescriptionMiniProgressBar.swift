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

    var body: some View {
        if !player.embeddingDisabled {
            Spacer()
                .frame(height: 6)
                .frame(maxWidth: .infinity)
                .background {
                    BackgroundProgressBar()
                }
                .foregroundStyle(Color.automaticBlack.opacity(0.8))
                .clipShape(Capsule())
                .font(.footnote)
        }
    }
}

#Preview {
    DescriptionMiniProgressBar()
        .environment(NavigationManager())
        .environment(PlayerManager.getDummy())
        .modelContainer(DataProvider.previewContainerFilled)
}
