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
        if let video = player.video, !player.embeddingDisabled {
            Button {
                navManager.selectedDetailPage = .description
                navManager.showDescriptionDetail = true
            } label: {
                HStack {
                    Image(systemName: Const.videoDescriptionSF)
                    if let published = video.publishedDate {
                        Text(Const.dotString)
                        Text(verbatim: "\(published.formattedToday)")
                    }

                    if let duration = video.duration?.formattedSeconds {
                        Text(Const.dotString)
                        Text(verbatim: "\(duration)")
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background {
                    BackgroundProgressBar()
                }
                .foregroundStyle(Color.automaticBlack.opacity(0.8))
                .clipShape(.rect(cornerRadius: 10))
            }
        }
    }
}
