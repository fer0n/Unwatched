//
//  ChapterSelection.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct ChapterDescriptionView: View {
    @Environment(NavigationManager.self) var navManager
    @Environment(PlayerManager.self) var player

    let video: Video
    var bottomSpacer: CGFloat = 0
    var isCompact = false
    var scrollToCurrent = false
    var isTransparent = false
    var showThumbnail = true

    var body: some View {
        let hasChapters = video.sortedChapters.isEmpty == false

        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: isCompact ? 8 : 10) {
                    if showThumbnail {
                        VideoDetailThumbnail(video: video)
                            .padding([.top, .horizontal], -5)
                    }

                    DescriptionDetailHeaderView(
                        video: video,
                        onTitleTap: onTitleTap)

                    if hasChapters {
                        ChapterList(
                            video: video,
                            isCompact: isCompact,
                            isTransparent: isTransparent
                        )
                        .padding(.top)
                        .padding(.bottom, 5)
                    }

                    ChapterSettingsMenu(video: player.video)

                    Spacer()
                        .frame(height: 10)

                    TranscriptDescriptionSelection(
                        video: video,
                        isCurrentVideo: video.youtubeId == player.video?.youtubeId,
                        )
                }
                .padding(.horizontal, showThumbnail ? 15 : isCompact ? 10 : 20)
                .padding(.top, showThumbnail ? 15 : isCompact ? 15 : 30)
                .frame(idealWidth: 500, maxWidth: 800, alignment: .leading)

                Spacer()
                    .frame(height: bottomSpacer)

                Spacer()
                    .frame(maxWidth: .infinity)
            }
            .onAppear {
                if hasChapters && player.video?.youtubeId == video.youtubeId {
                    if scrollToCurrent {
                    } else if navManager.scrollToCurrentChapter {
                        navManager.scrollToCurrentChapter = false
                    } else {
                        return
                    }
                    let chapter = player.previousChapter ?? player.currentChapter
                    let anchor: UnitPoint = player.previousChapter == nil ? .center : .top
                    proxy.scrollTo(
                        chapter?.persistentModelID,
                        anchor: anchor
                    )
                }
            }
        }
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
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ChapterDescriptionView(video: DataProvider.dummyVideo)
                .testEnvironments()
        }
}
