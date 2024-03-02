//
//  ChapterList.swift
//  Unwatched
//

import SwiftUI

struct ChapterList: View {
    @Environment(PlayerManager.self) var player

    var video: Video
    var isCompact: Bool = false

    var body: some View {
        let sorted = video.sortedChapters

        if !sorted.isEmpty {
            VStack(spacing: isCompact ? 4 : 10) {
                ForEach(sorted) { chapter in
                    let isCurrent = chapter == player.currentChapter
                    let foregroundColor: Color = isCurrent ? Color.backgroundColor : Color.myAccentColor
                    let backgroundColor: Color = isCurrent ? Color.myAccentColor : Color.myBackgroundGray

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
                            .padding(isCompact ? 3 : 10)
                            .background(
                                backgroundColor
                                    .clipShape(RoundedRectangle(cornerRadius: 15.0))
                            )
                            .opacity(chapter.isActive ? 1 : 0.6)
                            .id(chapter.persistentModelID)
                    }
                    .foregroundStyle(foregroundColor)
                    .tint(foregroundColor)
                }
            }
        }
    }

    func toggleChapter(_ chapter: Chapter) {
        chapter.isActive.toggle()
        player.handleChapterChange()
    }

    func setChapter(_ chapter: Chapter) {
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
