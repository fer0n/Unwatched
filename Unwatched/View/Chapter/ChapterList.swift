//
//  ChapterList.swift
//  Unwatched
//

import SwiftUI

struct ChapterList: View {
    @Environment(\.modelContext) var modelContext
    @Environment(PlayerManager.self) var player

    @State var toggleHaptic = false

    var video: Video
    var isCompact: Bool = false

    var body: some View {
        let sorted = video.sortedChapters

        if !sorted.isEmpty {
            VStack(spacing: isCompact ? 4 : 10) {
                ForEach(sorted) { chapter in
                    let isCurrent = chapter == player.currentChapter
                    let foregroundColor: Color = isCurrent ? Color.backgroundColor : Color.neutralAccentColor
                    let backgroundColor: Color = isCurrent ? Color.neutralAccentColor : Color.myBackgroundGray

                    Button {
                        if !chapter.isActive {
                            toggleChapter(chapter)
                        } else {
                            setChapter(chapter)
                        }
                    } label: {
                        ChapterListItem(chapter: chapter,
                                        toggleChapter: toggleChapter,
                                        timeText: getTimeText(chapter, isCurrent: isCurrent))
                            .padding(isCompact ? 4 : 10)
                            .padding(.trailing, 4)
                            .background(
                                backgroundColor
                                    .clipShape(.rect(cornerRadius: 15.0))
                            )
                            .opacity(chapter.isActive ? 1 : 0.6)
                            .id(chapter.persistentModelID)
                    }
                    .foregroundStyle(foregroundColor)
                    .tint(foregroundColor)
                }
            }
            .sensoryFeedback(Const.sensoryFeedback, trigger: toggleHaptic)
        }
    }

    func toggleChapter(_ chapter: Chapter) {
        toggleHaptic.toggle()
        chapter.isActive.toggle()
        if video == player.video {
            player.handleChapterChange()
        }
    }

    func setChapter(_ chapter: Chapter) {
        if video != player.video {
            video.elapsedSeconds = chapter.startTime
            player.playVideo(video)
            _ = VideoService.insertQueueEntries(videos: [video], modelContext: modelContext)
        }
        player.setChapter(chapter)
    }

    func getTimeText(_ chapter: Chapter, isCurrent: Bool) -> String {
        guard isCurrent,
              let endTime = chapter.endTime,
              let currentTime = player.currentTime else {
            return chapter.duration?.formattedSeconds ?? ""
        }
        let remaining = endTime - currentTime
        return "\(remaining.formattedSeconds ?? "") remaining"
    }
}

#Preview {
    ChapterList(video: Video.getDummy())
        .modelContainer(DataController.previewContainer)
        .environment(PlayerManager())
}
