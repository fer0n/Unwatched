//
//  ChapterList.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct ChapterList: View {
    @Environment(\.modelContext) var modelContext
    @Environment(PlayerManager.self) var player

    var video: Video
    var isCompact: Bool = false

    var body: some View {
        let sorted = video.sortedChapters

        if !sorted.isEmpty {
            VStack(spacing: isCompact ? 4 : 10) {
                ForEach(sorted) { chapter in
                    let isCurrent = chapter == player.currentChapter
                    let foregroundColor: Color = isCurrent ? Color.backgroundColor : Color.neutralAccentColor
                    let backgroundColor: Color = isCurrent ? Color.neutralAccentColor : Color.insetBackgroundColor

                    Button {
                        if !chapter.isActive {
                            toggleChapter(chapter)
                        } else {
                            setChapter(chapter)
                        }
                    } label: {
                        ChapterListItem(chapter: chapter,
                                        toggleChapter: toggleChapter,
                                        timeText: getTimeText(
                                            chapter, isCurrent: isCurrent
                                        ))
                            .padding(isCompact ? 4 : 10)
                            .padding(.trailing, 4)
                            .background(
                                backgroundColor
                                    .clipShape(.rect(cornerRadius: 15.0))
                                    .opacity(chapter.isActive ? 1 : 0.6)
                            )
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
        if video == player.video {
            player.handleChapterChange()
        }
    }

    func setChapter(_ chapter: Chapter) {
        if video != player.video {
            video.elapsedSeconds = chapter.startTime
            player.playVideo(video)
            VideoService.insertQueueEntries(videos: [video], modelContext: modelContext)
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
    let container = DataController.previewContainer
    let context = ModelContext(container)
    let player = PlayerManager()

    let video = Video.getDummy()
    context.insert(video)

    let ch1 = Chapter(title: "Chapter 1", time: 0, duration: 20, endTime: 20)
    let ch2 = Chapter(title: nil, time: 20, duration: 20, endTime: 40)
    let ch3 = Chapter(title: "Chapter 3", time: 40, duration: 20, endTime: 60)
    let ch4 = Chapter(title: "Chapter 4", time: 60, duration: 20, endTime: 80)
    let ch5 = Chapter(
        title: "Chapter 5 with a very very very very very long title",
        time: 80,
        duration: 20,
        endTime: 100
    )
    let ch6 = Chapter(title: "Chapter 6", time: 100, duration: 20, endTime: 120)
    let ch7 = Chapter(title: "Chapter 7", time: 120, duration: 20, endTime: 140)

    context.insert(ch1)
    context.insert(ch2)
    context.insert(ch3)
    context.insert(ch4)
    context.insert(ch5)
    context.insert(ch6)
    context.insert(ch7)

    video.chapters = [ch1, ch2, ch3, ch4, ch5, ch6, ch7]
    player.video = video
    player.currentChapter = ch3

    try? context.save()

    return ChapterList(video: video)
        .modelContainer(container)
        .environment(player)
}
