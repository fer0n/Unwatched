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

    @State private var dropTarget: String?
    @State private var draggingId: String?

    var video: Video
    var isCompact = false
    var isTransparent = false

    static let itemRadius: CGFloat = 15

    var padding: CGFloat {
        isCompact ? 4 : 6
    }

    var body: some View {
        if !chapters.isEmpty {
            LazyVStack(spacing: isCompact ? 4 : 10) {
                ForEach(chapters, id: \.chapterId) { chapter in
                    let isCurrent = chapter.chapterId == player.currentChapter?.chapterId
                    let foregroundColor: Color = isCurrent ? Color.backgroundColor : Color.neutralAccentColor
                    let backgroundColor: Color = isCurrent ? Color.neutralAccentColor : Color.insetBackgroundColor

                    ChapterListItem(
                        chapter: chapter,
                        toggleChapter: toggleChapter,
                        spacing: padding
                    )
                    .padding(.horizontal, padding + 2)
                    .padding(.vertical, padding)
                    .padding(.trailing, 4)
                    .background(
                        backgroundColor
                            .clipShape(.rect(cornerRadius: ChapterList.itemRadius))
                            .opacity(chapter.isActive ? 1 : 0.6)
                            .opacity(isTransparent ? 0.7 : 1)
                    )
                    .id(chapter.chapterId)
                    .opacity(draggingId == chapter.chapterId ? 0 : 1)
                    .overlay {
                        if !systemReorderingAvailable, dropTarget == chapter.chapterId {
                            RoundedRectangle(cornerRadius: ChapterList.itemRadius)
                                .stroke(Color.neutralAccentColor, lineWidth: 2)
                        }
                    }
                    .legacyReorderable(
                        id: chapter.chapterId,
                        canReorder: canReorder(chapter),
                        dropTarget: $dropTarget
                    ) { id in
                        moveChapter(id, onto: chapter)
                    }
                    .onTapGesture {
                        if !chapter.isActive {
                            toggleChapter(chapter)
                        } else {
                            Signal.log("Chapter.Jump")
                            setChapter(chapter)
                        }
                    }
                    .foregroundStyle(foregroundColor)
                    .tint(foregroundColor)
                    .contextMenu {
                        Button("copyUrl", systemImage: Const.copySF) {
                            if let text = UrlService.getShareUrl(video, timestamp: chapter.startTime) {
                                ClipboardService.set(text)
                            }
                        }
                    }
                    .accessibilityActions {
                        Button("playChapter") {
                            setChapter(chapter)
                        }
                        Button(chapter.isActive ? "disable" : "enable") {
                            toggleChapter(chapter)
                        }
                        if canReorder(chapter) {
                            Button("moveUp") {
                                moveChapter(chapter, by: -1)
                            }
                            Button("moveDown") {
                                moveChapter(chapter, by: 1)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                .reorderableIfAvailable()
            }
            .reorderContainerIfAvailable(for: SendableChapter.self, itemID: \.chapterId) { id, target in
                moveChapter(id, before: target)
            }
            .onDraggedItemChange(of: String.self) { id in
                draggingId = id
            }
        }
    }

    var chapters: [SendableChapter] {
        video.orderedChapterData
    }

    /// The generated intro/outro cover the start and the end of the video by definition, so they
    /// stay where they are — see `ChapterService.inPlaybackOrder`.
    func canReorder(_ chapter: SendableChapter) -> Bool {
        !chapter.isIntro && !chapter.isOutro
    }

    /// Drops the chapter carrying `id` into `target`'s slot. Like toggling, reordering is an edit
    /// that gives the video `Chapter` rows — see `ChapterService.setChapterOrder`.
    @discardableResult
    func moveChapter(_ id: String, onto target: SendableChapter) -> Bool {
        let current = chapters
        guard let from = current.firstIndex(where: { $0.chapterId == id }),
              let to = current.firstIndex(where: { $0.chapterId == target.chapterId }) else {
            return false
        }
        return moveChapter(current, from: from, to: to)
    }

    /// Puts the chapter carrying `id` in front of `target`, or last when there is none — what
    /// `reorderContainer` reports.
    func moveChapter(_ id: String, before target: String?) {
        let current = chapters
        guard let from = current.firstIndex(where: { $0.chapterId == id }) else {
            return
        }
        let insertAt = target.flatMap { id in current.firstIndex { $0.chapterId == id } } ?? current.count
        // the slot the moved chapter vacates shifts everything after it down one
        let to = insertAt > from ? insertAt - 1 : insertAt
        // the generated intro/outro hold the ends, so a drop past them lands alongside instead
        let leading = current.prefix { !canReorder($0) }.count
        let trailing = current.reversed().prefix { !canReorder($0) }.count
        moveChapter(current, from: from, to: min(max(to, leading), current.count - 1 - trailing))
    }

    func moveChapter(_ chapter: SendableChapter, by offset: Int) {
        let current = chapters
        guard let from = current.firstIndex(where: { $0.chapterId == chapter.chapterId }) else {
            return
        }
        moveChapter(current, from: from, to: from + offset)
    }

    @discardableResult
    private func moveChapter(_ current: [SendableChapter], from: Int, to: Int) -> Bool {
        guard from != to,
              current.indices.contains(from),
              current.indices.contains(to),
              canReorder(current[from]),
              canReorder(current[to]),
              guardPremium() else {
            return false
        }
        var reordered = current
        withAnimation {
            let moved = reordered.remove(at: from)
            reordered.insert(moved, at: to)
            ChapterService.setChapterOrder(reordered, of: video)
        }
        Signal.log("Chapter.Reorder")
        return true
    }

    /// Toggling, like reordering, is an action that needs a row — see `ChapterService.materialize`.
    func toggleChapter(_ chapter: SendableChapter) {
        guard !chapter.isActive || guardPremium() else {
            return
        }
        if chapter.isIntro || chapter.isOutro {
            if chapter.isIntro {
                video.keepIntro = !(video.keepIntro ?? false)
            } else {
                video.keepOutro = !(video.keepOutro ?? false)
            }
            try? video.modelContext?.save()
            if video == player.video {
                player.handleChapterChange()
            }
            return
        }
        // enabling something only the channel's auto-skip list turned off needs no row
        if !chapter.isActive, video.subscription?.autoSkips(chapter.title) == true {
            video.subscription?.setAutoSkip(chapter.title, false)
            chapterDidChange()
            return
        }
        guard let row = ChapterService.materialize(chapter, of: video) else {
            Log.warning("toggleChapter: no row for \(chapter)")
            return
        }
        row.isActive = !chapter.isActive
        video.subscription?.setAutoSkip(chapter.title, !row.isActive)
        chapterDidChange()
    }

    private func chapterDidChange() {
        video.chaptersDidChange()
        try? video.modelContext?.save()
        if video == player.video {
            player.handleChapterChange()
            // the page seeks by the chapters it was handed, so the edit has to reach it too
            player.backend.setChapterMarkers(force: false)
        }
    }

    func setChapter(_ chapter: SendableChapter) {
        if video != player.video {
            video.elapsedSeconds = chapter.startTime
            player.playVideo(video)
            Signal.playbackStarted("detail")
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
    player.currentChapter = ch3.toExport

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
                    proxy.scrollTo(player.currentChapter?.chapterId, anchor: .center)
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
