//
//  ChapterSelection.swift
//  Unwatched
//

import SwiftUI

struct ChapterSelection: View {
    var video: Video
    var chapterManager: ChapterManager

    func toggleChapter(_ chapter: Chapter) {
        chapter.isActive.toggle()
        chapterManager.handleChapterChange()
    }

    func setChapter(_ chapter: Chapter) {
        chapterManager.setChapter(chapter)
    }

    func getTimeText(_ chapter: Chapter, isCurrent: Bool) -> String {
        guard isCurrent,
              let endTime = chapter.endTime,
              let currentTime = chapterManager.currentTime else {
            return chapter.duration?.formattedSeconds ?? ""
        }
        let remaining = endTime - currentTime
        return "\(remaining.formattedSeconds ?? "") remaining"
    }

    var body: some View {
        if !video.chapters.isEmpty {
            ForEach(video.sortedChapters) { chapter in
                let isCurrent = chapter == chapterManager.currentChapter
                let foregroundColor: Color = isCurrent ? Color.backgroundColor : Color.accentColor
                let backgroundColor: Color = isCurrent ? Color.accentColor : Color.myBackgroundGray

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
                        .padding(10)
                        .background(
                            backgroundColor
                                .clipShape(RoundedRectangle(cornerRadius: 15.0))
                        )
                        .opacity(chapter.isActive ? 1 : 0.6)
                }
                .tint(foregroundColor)
            }
        }
    }
}

// #Preview {
//    ChapterSelection()
// }
