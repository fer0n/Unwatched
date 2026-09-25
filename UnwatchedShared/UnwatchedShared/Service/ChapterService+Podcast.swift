//
//  ChapterService+Podcast.swift
//  UnwatchedShared
//

import Foundation
import SwiftData

extension ChapterService {
    @MainActor
    private static var loadedPodcastChapterIds = Set<String>()

    @MainActor
    public static func allowPodcastChapterRefetch(youtubeId: String) {
        loadedPodcastChapterIds.remove(youtubeId)
    }

    /// Caches chapters from the chapters file, the audio file or the feed; `true` if any were found.
    @MainActor
    public static func fetchPodcastChapters(for video: Video) async -> Bool {
        // stored rows are user edits
        guard video.chapters?.isEmpty ?? true,
              fetchedChapters(youtubeId: video.youtubeId, duration: video.duration) == nil else {
            return false
        }
        let youtubeId = video.youtubeId
        guard loadedPodcastChapterIds.insert(youtubeId).inserted else {
            return false
        }
        let duration = video.duration
        let chaptersUrl = video.chaptersUrl
        let feedUrl = video.subscription?.link
        let mediaUrl = PodcastDownloadStore.playbackUrl(for: video) ?? video.mediaUrl

        var chapters: [SendableChapter]?
        if let chaptersUrl {
            chapters = await PodcastService.fetchChapters(chaptersUrl, duration: duration)
        }
        if let mediaUrl, chapters?.contains(where: { $0.imageUrl != nil }) != true {
            let embedded = await PodcastService.embeddedChapters(
                mediaUrl, duration: duration, episodeId: youtubeId
            )
            if let listed = chapters {
                // e.g. Lage der Nation: titles in the file, images in the frames
                if let embedded, embedded.contains(where: { $0.imageUrl != nil }) {
                    chapters = PodcastService.mergingImages(from: embedded, into: listed)
                }
            } else {
                chapters = embedded
            }
        }
        if chapters == nil, let feedUrl {
            chapters = await PodcastService.inlineChapters(feedUrl: feedUrl, episodeId: youtubeId)
        }
        guard let chapters else {
            // retry later: a finished download may have them
            loadedPodcastChapterIds.remove(youtubeId)
            return false
        }
        cachePodcastChapters(chapters, youtubeId: youtubeId)
        return true
    }
}
