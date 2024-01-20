//
//  ChapterSelection.swift
//  Unwatched
//

import SwiftUI

struct ChapterSelection: View {
    @Environment(PlayerManager.self) var player

    var body: some View {
        if player.video?.chapters.isEmpty == false,
           let sortedChapters = player.video?.sortedChapters {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack {
                        ForEach(sortedChapters) { chapter in
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
                                    .padding(10)
                                    .background(
                                        backgroundColor
                                            .clipShape(RoundedRectangle(cornerRadius: 15.0))
                                    )
                                    .opacity(chapter.isActive ? 1 : 0.6)
                                    .id(chapter.persistentModelID)
                            }
                            .tint(foregroundColor)
                        }
                    }
                    .padding(.top, 30)
                    .padding(.bottom, 50)
                    .padding(.horizontal)
                }
                .onAppear {
                    proxy.scrollTo(player.currentChapter?.persistentModelID, anchor: .center)
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

// #Preview {
//    ChapterSelection()
// }
