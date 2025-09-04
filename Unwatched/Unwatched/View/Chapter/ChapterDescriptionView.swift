//
//  ChapterSelection.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct ChapterDescriptionView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(NavigationManager.self) var navManager
    @Environment(PlayerManager.self) var player

    let video: Video
    var bottomSpacer: CGFloat = 0
    var isCompact = false
    var scrollToCurrent = false
    var isTransparent = false

    var body: some View {
        let hasChapters = video.sortedChapters.isEmpty == false

        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: isCompact ? 8 : 10) {
                    DescriptionDetailHeaderView(
                        video: video,
                        smallTitle: isCompact,
                        onTitleTap: onTitleTap)

                    if hasChapters {
                        ChapterList(
                            video: video,
                            isCompact: isCompact,
                            isTransparent: isTransparent
                        )
                        .padding(.vertical)
                    }

                    if showGenerateButton {
                        if #available(iOS 26, macOS 26.0, *) {
                            GenerateChaptersButton(
                                video: player.video,
                                transcriptUrl: video.youtubeId == player.video?.youtubeId ? player.transcriptUrl : nil,
                                )
                            .requiresPremium() {
                                dismiss()
                            }
                        }
                    }

                    if hasChapters || showGenerateButton {
                        Spacer()
                            .frame(height: 7)
                    }

                    TranscriptDescriptionSelection(
                        video: video,
                        isCurrentVideo: video.youtubeId == player.video?.youtubeId,
                        )
                }
                .padding(.horizontal, isCompact ? 10 : 20)
                .padding(.top, isCompact ? 15 : 30)
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
        .padding(.top, 2)
        .tint(.neutralAccentColor)
    }

    func onTitleTap() {
        if let url = video.url?.absoluteString {
            navManager.openUrlInApp(.url(url))
            navManager.videoDetail = nil
        }
    }

    var showGenerateButton: Bool {
        if #available(iOS 26, macOS 26.0, *), video.chapters?.isEmpty != false {
            return true
        }
        return false
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
