//
//  InboxCardChapters.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// Tappable chapter chips that jump straight to that part of the video
struct InboxCardChapters: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PlayerManager.self) private var player

    let video: Video
    let chapters: [Chapter]
    var bleedEdges: Edge.Set = .horizontal

    @ScaledMetric private var fontSize = 13
    @ScaledMetric private var singleLineChipWidth = 160
    @ScaledMetric private var maxChipWidth = 300

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 6) {
                ForEach(chapters) { chapter in
                    chip(for: chapter)
                }
            }
            .padding(bleedEdges, InboxCard.contentPadding)
        }
        .padding(bleedEdges, -InboxCard.contentPadding)
        // a scroll view takes all the height it's offered, leaving none for the description
        .fixedSize(horizontal: false, vertical: true)
    }

    private func chip(for chapter: Chapter) -> some View {
        Button {
            setChapter(chapter)
        } label: {
            TwoRowChipLayout(singleLineWidth: singleLineChipWidth, maxWidth: maxChipWidth) {
                ForEach(TwoRowChipLayout.Variant.allCases, id: \.rawValue) { variant in
                    chipLabel(for: chapter, variant)
                        .multilineTextAlignment(.leading)
                }
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.quaternary, in: .rect(cornerRadius: 12))
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    /// One run of text, so the duration can flow inline after a wrapped title
    private func chipLabel(for chapter: Chapter, _ variant: TwoRowChipLayout.Variant) -> Text {
        var title = AttributedString(chapter.titleTextForced)
        title.font = .system(size: fontSize, weight: .semibold)

        guard let duration = chapter.duration?.formattedSeconds else {
            return Text(title)
        }
        var time = AttributedString("\(variant.separator)\(duration)")
        time.font = .system(size: fontSize)
        time.foregroundColor = .secondary
        return Text(title + time)
    }

    private func setChapter(_ chapter: Chapter) {
        if video != player.video {
            video.elapsedSeconds = chapter.startTime
            player.playVideo(video)
            Signal.playbackStarted(VideoListContext.inboxCards.rawValue)
            VideoService.insertQueueEntries(videos: [video], modelContext: modelContext)
        }
        player.setChapter(chapter)
        Signal.log("Chapter.Jump")
    }
}

#Preview {
    InboxCardChapters(
        video: DataProvider.dummyVideo,
        chapters: [
            Chapter(title: "Intro", time: 0, duration: 42),
            Chapter(title: "A considerably longer chapter title that needs to wrap", time: 42, duration: 305),
            Chapter(title: "Two words", time: 347, duration: 90),
            Chapter(title: "Supercalifragilisticexpialidocious", time: 437, duration: 12)
        ]
    )
    .previewEnvironments()
    .padding()
    .background(Color.backgroundColor)
}
