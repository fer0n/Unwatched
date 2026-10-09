//
//  GetChapters.swift
//  Unwatched
//

import AppIntents
import SwiftData
import UnwatchedShared

struct GetChapters: AppIntent {
    static var title: LocalizedStringResource { "getChapters" }
    static let description = IntentDescription("getChaptersDescription")
    static var supportedModes: IntentModes { .background }

    @Parameter(title: "mediaUrl")
    var videoUrl: URL?

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<ChaptersResult> {
        Signal.log("Shortcut.GetChapters")
        ChapterAutomationStatus.shared.recordShortcutRun()
        let video = try VideoService.getVideoOrCurrent(videoUrl)
        if video.isPodcast {
            _ = await ChapterService.fetchPodcastChapters(for: video)
        }

        let rows = video.sortedChapters
        let timeline = rows.isEmpty ? video.derivedChapters : rows.map(\.toExport)
        let text = timeline.map(Self.line).joined(separator: "\n")

        return .result(value: ChaptersResult(
            text: text,
            chapterCount: ChapterAutomation.ownChapterCount(video),
            segmentCount: timeline.filter(Self.isSegment).count
        ))
    }

    private static func line(_ chapter: SendableChapter) -> String {
        let line = "\(ChapterService.secondsToTimestamp(chapter.startTime)) \(chapter.title ?? "")"
        guard let label = segmentLabel(chapter) else { return line }
        return "\(line) [\(label)]"
    }

    private static func isSegment(_ chapter: SendableChapter) -> Bool {
        segmentLabel(chapter) != nil
    }

    private static func segmentLabel(_ chapter: SendableChapter) -> String? {
        switch chapter.category {
        case .sponsor: "sponsor"
        case .selfpromo: "self promotion"
        default: nil
        }
    }
}

struct ChaptersResult: TransientAppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "chapters"

    @Property(title: "chapters")
    var text: String

    @Property(title: "chapterCount")
    var chapterCount: Int

    @Property(title: "segmentCount")
    var segmentCount: Int

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(stringLiteral: text)
    }

    init() {
        self.text = ""
        self.chapterCount = 0
        self.segmentCount = 0
    }

    init(text: String, chapterCount: Int, segmentCount: Int) {
        self.text = text
        self.chapterCount = chapterCount
        self.segmentCount = segmentCount
    }
}
