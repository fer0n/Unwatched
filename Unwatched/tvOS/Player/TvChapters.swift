//
//  TvChapters.swift
//  UnwatchedTV
//

import AVKit
import UnwatchedShared

/// Hands a video's chapters to the system player, which turns them into a chapter list in the
/// info panel and markers on the scrubber — no custom menu needed.
enum TvChapters {
    static func markerGroups(for video: Video) -> [AVNavigationMarkersGroup] {
        let chapters = video.sortedChapters
        guard !chapters.isEmpty else { return [] }

        let markers = chapters.enumerated().compactMap { index, chapter -> AVTimedMetadataGroup? in
            let next = chapters.dropFirst(index + 1).first
            // The last chapter usually has no end of its own; without a duration to fall back on
            // there's no range to place it in, so it has to go.
            guard let end = chapter.endTime ?? next?.startTime ?? video.duration,
                  end > chapter.startTime else {
                return nil
            }
            return AVTimedMetadataGroup(
                items: [titleItem(chapter.title ?? label(for: chapter.category))],
                timeRange: CMTimeRange(
                    start: CMTime(seconds: chapter.startTime, preferredTimescale: 600),
                    end: CMTime(seconds: end, preferredTimescale: 600)
                )
            )
        }

        return markers.isEmpty ? [] : [AVNavigationMarkersGroup(title: nil, timedNavigationMarkers: markers)]
    }

    private static func titleItem(_ title: String) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = .commonIdentifierTitle
        item.value = title as NSString
        item.extendedLanguageTag = "und"
        return item
    }

    /// SponsorBlock segments come without a title of their own.
    private static func label(for category: ChapterCategory?) -> String {
        switch category {
        case .sponsor: String(localized: "categorySponsor")
        case .filler: String(localized: "categoryFiller")
        case .intro: String(localized: "categoryIntro")
        case .selfpromo: String(localized: "categorySelfpromo")
        case .interaction: String(localized: "categoryInteraction")
        case .outro: String(localized: "categoryOutro")
        case .preview: String(localized: "categoryPreview")
        case .musicOfftopic: String(localized: "categoryMusicOfftopic")
        default: "–"
        }
    }
}
