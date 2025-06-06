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
    var isCompact = false
    var scrollToCurrent = false

    var body: some View {
        let hasChapters = video.sortedChapters.isEmpty == false

        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: isCompact ? 8 : 10) {
                    DescriptionDetailHeaderView(
                        video: video,
                        smallTitle: isCompact,
                        onTitleTap: onTitleTap,
                        setShowMenu: setShowMenu)

                    if hasChapters {
                        ChapterList(video: video, isCompact: isCompact)
                            .padding(.vertical)
                    } else {
                        Spacer()
                            .frame(height: 7)
                    }

                    DescriptionDetailView(video: video)
                }
                .padding(.horizontal, isCompact ? 10 : 20)
                .padding(.top, isCompact ? 10 : 30)
                .frame(idealWidth: 500, maxWidth: 800, alignment: .leading)

                Spacer()
                    .frame(height: bottomSpacer)

                Spacer()
                    .frame(maxWidth: .infinity)
            }
            .onAppear {
                if hasChapters && player.video == video {
                    let anchor: UnitPoint?
                    if scrollToCurrent {
                        anchor = .center
                    } else if navManager.scrollToCurrentChapter {
                        navManager.scrollToCurrentChapter = false
                        anchor = .top
                    } else {
                        return
                    }
                    proxy.scrollTo(
                        player.currentChapter?.persistentModelID,
                        anchor: anchor
                    )
                }
            }
        }
        .padding(.top, 2)
        .tint(.neutralAccentColor)
    }

    func onTitleTap() {
        if let url = video.url?.absoluteString {
            navManager.openUrlInApp(.url(url))
            navManager.videoDetail = nil
        }
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
