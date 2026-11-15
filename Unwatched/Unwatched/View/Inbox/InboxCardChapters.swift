//
//  InboxCardChapters.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared
import SwiftData

/// Tappable chapter chips that jump straight to that part of the video
struct InboxCardChapters: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PlayerManager.self) private var player

    let video: Video
    let chapters: [SendableChapter]
    var bleedEdges: Edge.Set = .horizontal

    @ScaledMetric private var fontSize = 13
    @ScaledMetric private var singleLineChipWidth = 160
    @ScaledMetric private var maxChipWidth = 300

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 6) {
                ForEach(chapters, id: \.chapterId) { chapter in
                    chip(for: chapter)
                }
            }
            .padding(bleedEdges, InboxCard.contentPadding)
        }
        .padding(bleedEdges, -InboxCard.contentPadding)
        // a scroll view takes all the height it's offered, leaving none for the description
        .fixedSize(horizontal: false, vertical: true)
    }

    private func chip(for chapter: SendableChapter) -> some View {
        Button {
            setChapter(chapter)
        } label: {
            TwoRowChipLayout(singleLineWidth: singleLineChipWidth, maxWidth: maxChipWidth) {
                ForEach(TwoRowChipLayout.Variant.allCases, id: \.rawValue) { variant in
                    switch variant {
                    case .stacked: chipLabel(for: chapter, separator: "\n")
                    case .inline: chipLabel(for: chapter, separator: "  ")
                    case .truncated: truncatedChipLabel(for: chapter)
                    }
                }
            }
            .multilineTextAlignment(.leading)
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.quaternary, in: .rect(cornerRadius: 12))
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(chipLabel(for: chapter, separator: ", "))
    }

    private var titleFont: Font { .system(size: fontSize, weight: .semibold) }
    private var durationFont: Font { .system(size: fontSize) }

    /// One run of text, so the duration can flow inline after a wrapped title
    private func chipLabel(for chapter: SendableChapter, separator: String) -> Text {
        var title = AttributedString(chapter.titleText(fallback: video.title))
        title.font = titleFont

        guard let duration = chapter.duration?.formattedSeconds else {
            return Text(title)
        }
        var time = AttributedString("\(separator)\(duration)")
        time.font = durationFont
        time.foregroundColor = .secondary
        return Text(title + time)
    }

    private func truncatedChipLabel(for chapter: SendableChapter) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            Text(chapter.titleText(fallback: video.title))
                .font(titleFont)
                .lineLimit(2)
            if let duration = chapter.duration?.formattedSeconds {
                Text("  \(duration)")
                    .font(durationFont)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
        }
    }

    private func setChapter(_ chapter: SendableChapter) {
        if video != player.video {
            video.elapsedSeconds = chapter.startTime
            player.playVideo(video)
            Signal.playbackStarted(VideoListContext.inboxCards.rawValue)
            VideoService.insertQueueEntries(videos: [video], modelContext: modelContext)
        }
        player.setChapter(chapter)
        Signal.interaction("Chapter.Jump")
    }
}

#Preview {
    InboxCardChapters(
        video: DataProvider.dummyVideo,
        chapters: [
            SendableChapter(title: "Intro", startTime: 0, duration: 42),
            SendableChapter(
                title: "A considerably longer chapter title that needs to wrap",
                startTime: 42,
                duration: 305
            ),
            SendableChapter(title: "Two words", startTime: 347, duration: 90),
            SendableChapter(title: "Supercalifragilisticexpialidocious", startTime: 437, duration: 12),
            SendableChapter(
                title: "A chapter title so long that it can't possibly fit into two rows, even at the widest a chip gets",
                startTime: 449,
                duration: 600
            )
        ]
    )
    .previewEnvironments()
    .padding()
    .background(Color.backgroundColor)
}
