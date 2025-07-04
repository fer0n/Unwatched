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
    var isCompact = false
    var isTransparent = false

    var padding: CGFloat {
        isCompact ? 4 : 6
    }

    var body: some View {
        if !chapters.isEmpty {
            LazyVStack(spacing: isCompact ? 4 : 10) {
                ForEach(chapters) { chapter in
                    let isCurrent = chapter.persistentModelID == player.currentChapter?.persistentModelID
                    let foregroundColor: Color = isCurrent ? Color.backgroundColor : Color.neutralAccentColor
                    let backgroundColor: Color = isCurrent ? Color.neutralAccentColor : Color.insetBackgroundColor

                    ChapterListItem(
                        chapter: chapter,
                        toggleChapter: toggleChapter,
                        spacing: padding,
                        currentTime: isCurrent ? player.currentTime : nil,
                        )
                    .padding(.horizontal, padding + 2)
                    .padding(.vertical, padding)
                    .padding(.trailing, 4)
                    .background(
                        backgroundColor
                            .clipShape(.rect(cornerRadius: 15.0))
                            .opacity(chapter.isActive ? 1 : 0.6)
                            .opacity(isTransparent ? 0.7 : 1)
                    )
                    .id(chapter.persistentModelID)
                    .onTapGesture {
                        if !chapter.isActive {
                            toggleChapter(chapter)
                        } else {
                            setChapter(chapter)
                        }
                    }
                    .foregroundStyle(foregroundColor)
                    .tint(foregroundColor)
                    .accessibilityActions {
                        Button("playChapter") {
                            setChapter(chapter)
                        }
                        Button(chapter.isActive ? "disable" : "enable") {
                            toggleChapter(chapter)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    var chapters: [Chapter] {
        Video.getSortedChapters(video.mergedChapters, video.chapters)
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
}

#Preview {

    let container = DataProvider.previewContainer
    let context = ModelContext(container)
    let player = PlayerManager()

    let video = Video.getDummy()
    context.insert(video)

    let ch1 = Chapter(
        title: "Chapter 1 Chapter 1 Chapter 1 Chapter 1 Chapter 1 Chapter 1 Chapter 1 Chapter 1 Chapter 1 Chapter 1",
        time: 0,
        duration: 20,
        endTime: 20
    )
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

    video.chapters = [ch1, ch2, ch3, ch4] // , ch5, ch6, ch7
    player.video = video
    player.currentChapter = ch3

    try? context.save()

    return (
        ZStack {
            HStack {
                Color.red
                    .frame(maxWidth: .infinity)
                Color.blue
                    .frame(maxWidth: .infinity)
            }
        }
        .popover(isPresented: .constant(true), arrowEdge: .trailing) {
            ScrollViewReader { proxy in
                ScrollView {
                    ChapterList(video: video, isCompact: true, isTransparent: true)
                        .padding(10)
                }
                // .background(.blue)
                .onAppear {
                    proxy.scrollTo(player.currentChapter?.persistentModelID, anchor: .center)
                }
                .scrollIndicators(.hidden)
            }
            .frame(minWidth: 200, idealWidth: 300, maxWidth: 350)
            .presentationCompactAdaptation(.popover)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .preferredColorScheme(.dark)
    )
    .modelContainer(container)
    .environment(player)
}
