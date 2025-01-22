//
//  ChapterSelection.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct ChapterDescriptionView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(PlayerManager.self) var player
    @Environment(NavigationManager.self) var navManager

    let video: Video
    var bottomSpacer: CGFloat = 0
    var setShowMenu: (() -> Void)?

    var body: some View {
        let hasChapters = video.sortedChapters.isEmpty == false

        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    DescriptionDetailHeaderView(video: video, onTitleTap: {
                        if let url = video.url?.absoluteString {
                            navManager.openUrlInApp(.url(url))
                            navManager.videoDetail = nil
                        }
                    }, setShowMenu: setShowMenu)

                    if hasChapters {
                        ChapterList(video: video)
                            .padding(.vertical)
                    }

                    DescriptionDetailView(video: video)
                }
                .padding(.horizontal, 20)
                .padding(.top, 30)
                .frame(maxWidth: 800, alignment: .leading)

                Spacer()
                    .frame(height: bottomSpacer)

                Spacer()
                    .frame(maxWidth: .infinity)
            }
            .onAppear {
                if hasChapters && player.video == video && navManager.scrollToCurrentChapter {
                    proxy.scrollTo(
                        player.currentChapter?.persistentModelID,
                        anchor: .top
                    )
                    navManager.scrollToCurrentChapter = false
                }
            }
        }
        .padding(.top, 2)
        .tint(.neutralAccentColor)
    }
}

#Preview {
    ChapterDescriptionView(video: DataProvider.dummyVideo)
        .modelContainer(DataProvider.previewContainerFilled)
        .environment(PlayerManager.getDummy())
        .environment(NavigationManager())
        .environment(RefreshManager())
        .environment(SubscribeManager())
        .environment(ImageCacheManager())
        .environment(SheetPositionReader())
}
