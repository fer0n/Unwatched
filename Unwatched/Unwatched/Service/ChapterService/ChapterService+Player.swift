//
//  ChapterService+Player.swift
//  Unwatched
//
//  Chapter-service methods that touch the player/UI layer, kept in the main app target.
//  The rest of ChapterService lives in UnwatchedShared so the Share Extension can use it too.
//

import Foundation
import SwiftData
import UnwatchedShared

extension ChapterService {
    /// Podcast episodes whose chapters this session already fetched, so the same episode isn't asked for twice.
    @MainActor
    private static var loadedPodcastChapterIds = Set<String>()

    static func updateDuration(
        _ video: Video,
        duration: Double
    ) {
        // has to be the video's own context: a filler chapter from a foreign one can't be attached
        guard let context = video.modelContext else {
            Log.warning("updateDuration: video has no context")
            return
        }

        if let lastNormalChapter = (video.chapters ?? []).max(by: { $0.startTime < $1.startTime }) {
            if  lastNormalChapter.endTime == nil, duration > lastNormalChapter.startTime {
                lastNormalChapter.endTime = duration
                lastNormalChapter.duration = duration - lastNormalChapter.startTime
            }
        }

        if var chapters = video.mergedChapters?.sorted(by: { $0.startTime < $1.startTime }) {
            let hasChanges = fillOutEmptyEndTimes(chapters: &chapters, duration: duration, context: context)
            if hasChanges {
                attach(chapters, to: video, merged: true)
            }
        }

        try? context.save()
    }

    @MainActor
    static func insertChapters(_ chapters: [SendableChapter], for video: Video) {
        guard let context = video.modelContext else {
            Log.warning("insertChapters: video has no context")
            return
        }
        if reconcileChapters(chapters, for: video).hasChanges {
            CleanupService.deleteMergedChapters(from: video, context)
            // rows now describe this video; a derived copy alongside them would only drift
            invalidateDerivedChapters(youtubeId: video.youtubeId)
        }
        try? context.save()

        if video.youtubeId == PlayerManager.shared.video?.youtubeId {
            PlayerManager.shared.video = video
            PlayerManager.shared.handleChapterRefresh(forceRefresh: true)
        }
    }

    /// Podcast chapters come from the feed itself (Podlove chapters, or timestamps in the description); the two that
    /// have to be fetched are a `podcast:chapters` file and the chapter frames inside the episode's own audio file.
    @MainActor
    static func loadPodcastChapters(for video: Video) {
        // rows mean the user has edited this episode's chapters; a cached set means they're already in hand
        guard video.chapters?.isEmpty ?? true,
              fetchedChapters(youtubeId: video.youtubeId, duration: video.duration) == nil else {
            return
        }
        let youtubeId = video.youtubeId
        guard loadedPodcastChapterIds.insert(youtubeId).inserted else {
            return
        }
        let videoId = video.persistentModelID
        let duration = video.duration
        let chaptersUrl = video.chaptersUrl
        let feedUrl = video.subscription?.link
        // the downloaded file where there is one: reading it works offline, and doesn't depend on the show's server
        // honouring a range request
        let mediaUrl = PodcastDownloadStore.playbackUrl(for: video) ?? video.mediaUrl

        Task {
            // the feed's own file first: it's a small JSON the show maintains by hand, where the file's frames are
            // whatever the encoder happened to write
            var chapters: [SendableChapter]?
            if let chaptersUrl {
                chapters = await PodcastService.fetchChapters(chaptersUrl, duration: duration)
            }
            if chapters == nil, let mediaUrl {
                chapters = await PodcastService.embeddedChapters(mediaUrl, duration: duration, episodeId: youtubeId)
            }
            if chapters == nil, let feedUrl {
                // inline markers came with the episode and were cached; this is how they come back once that entry
                // has been cleaned up
                chapters = await PodcastService.inlineChapters(feedUrl: feedUrl, episodeId: youtubeId)
            }
            guard let chapters else {
                // nothing found: let the next trigger try again — the download landing since turns a request that
                // reached nothing into a local read
                loadedPodcastChapterIds.remove(youtubeId)
                return
            }
            cachePodcastChapters(chapters, youtubeId: youtubeId)

            guard let video: Video = DataProvider.mainContext.existingModel(for: videoId) else {
                return
            }
            // the cache publishes nothing of its own, and neither does the player
            video.chaptersDidChange()
            if video.youtubeId == PlayerManager.shared.video?.youtubeId {
                PlayerManager.shared.handleChapterRefresh(forceRefresh: true)
            }
        }
    }

    /// Same, for an episode that isn't loaded — the download manager knows only the id.
    @MainActor
    static func loadPodcastChapters(youtubeId: String) {
        var fetch = FetchDescriptor<Video>(predicate: #Predicate { $0.youtubeId == youtubeId })
        fetch.fetchLimit = 1
        guard let video = try? DataProvider.mainContext.fetch(fetch).first else {
            return
        }
        loadPodcastChapters(for: video)
    }

    /// The `Chapter` row for a chapter the user just acted on, creating the video's rows the first time one is
    /// needed.
    @MainActor
    static func materialize(
        _ chapter: SendableChapter,
        of video: Video
    ) -> Chapter? {
        // the generated intro/outro chapters aren't among the video's own, and their start times would otherwise
        // match whichever row sits at that end of the video
        guard !chapter.isIntro, !chapter.isOutro else {
            Log.warning("materialize: intro/outro chapters have no row, see Video.keepIntro")
            return nil
        }
        if let id = chapter.persistentId,
           let row: Chapter = video.modelContext?.existingModel(for: id) {
            return row
        }

        let reconciled = reconcileChapters(video.ownChapterData, for: video)
        // the rows are the source of truth from here on; a derived copy alongside them would only
        // be a second one that drifts
        invalidateDerivedChapters(youtubeId: video.youtubeId)

        return reconciled.chapters.first { $0.startTime == chapter.startTime }
    }

    /// Puts a video's chapters back to what its description says, dropping whatever was edited into them.
    @MainActor
    static func restoreChapters(for video: Video) {
        guard let context = video.modelContext else {
            Log.warning("restoreChapters: video has no context")
            return
        }

        let rows = video.chapters ?? []
        video.chapters = []
        for row in rows {
            context.delete(row)
        }
        CleanupService.deleteMergedChapters(from: video, context)
        video.keepIntro = nil
        video.keepOutro = nil
        invalidateDerivedChapters(youtubeId: video.youtubeId)
        // the cached copy went with it, so an episode is free to fetch its chapters again
        loadedPodcastChapterIds.remove(video.youtubeId)
        video.chaptersDidChange()
        try? context.save()

        if video.youtubeId == PlayerManager.shared.video?.youtubeId {
            PlayerManager.shared.video = video
            PlayerManager.shared.handleChapterRefresh(forceRefresh: true)
        }
    }
}
