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

    /// Merges segments that didn't come from SponsorBlock — what the `mergeChapters` shortcut hands over, and
    /// the only way a podcast episode gets sponsor segments at all — the same way SponsorBlock's own are merged.
    ///
    /// The video's own chapters are left as they are; the result goes into `mergedChapters`, so running this
    /// again replaces the previous segments instead of splitting the chapters a second time.
    @MainActor
    @discardableResult
    static func mergeSegments(_ segments: [SendableChapter], into video: Video) -> Bool {
        guard let context = video.modelContext else {
            Log.warning("mergeSegments: video has no context")
            return false
        }

        let cleanedSegments = cleanExternalChapters(segments)
        guard !cleanedSegments.isEmpty else {
            return false
        }

        let videoChapters = video.ownChapterData
        Log.info("mergeSegments, old: \(videoChapters)")

        var newChapters = videoChapters.isEmpty
            ? generateChapters(from: cleanedSegments, videoDuration: video.duration)
            : mergeSponsorSegments(videoChapters, sponsorSegments: cleanedSegments, duration: video.duration)
        let settings = video.sponsorBlockSettings
        skipSponsorBlockSegments(
            in: &newChapters,
            sponsorSetting: settings.sponsor,
            selfPromoSetting: settings.selfPromo
        )
        Log.info("mergeSegments, new: \(newChapters)")

        updateIfNeeded(newChapters, video)
        try? context.save()
        notifyPlayer(of: video)
        return true
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
        // these are different chapters, so whatever slots the old ones were dragged into mean nothing
        clearChapterOrder(of: video)
        try? context.save()

        notifyPlayer(of: video, refresh: true)
    }

    /// Hands the player a video it is already showing, so an edit to its chapters reaches playback.
    @MainActor
    private static func notifyPlayer(of video: Video, refresh: Bool = false) {
        guard video.youtubeId == PlayerManager.shared.video?.youtubeId else {
            return
        }
        if refresh {
            PlayerManager.shared.video = video
            PlayerManager.shared.handleChapterRefresh(forceRefresh: true)
        } else {
            PlayerManager.shared.handleChapterChange()
        }
        // the page seeks by the chapters it was handed, so an edit has to reach it too
        PlayerManager.shared.backend.setChapterMarkers(force: false)
    }

    private static func clearChapterOrder(of video: Video) {
        for row in video.allChapterRows where row.order != nil {
            row.order = nil
        }
    }

    @MainActor
    static func loadPodcastChapters(for video: Video) {
        let videoId = video.persistentModelID
        Task {
            guard await fetchPodcastChapters(for: video),
                  let video: Video = DataProvider.mainContext.existingModel(for: videoId) else {
                return
            }
            // the cache publishes nothing of its own, and neither does the player
            video.chaptersDidChange()
            notifyPlayer(of: video, refresh: true)
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

    /// Puts a video's chapters into the order the user dragged them into. Ordering is an edit like
    /// toggling one off, so it materializes the video's rows the same way — see `materialize`.
    ///
    /// - Parameter chapters: every chapter of the video, in the new order.
    @MainActor
    static func setChapterOrder(_ chapters: [SendableChapter], of video: Video) {
        guard let context = video.modelContext else {
            Log.warning("setChapterOrder: video has no context")
            return
        }

        var rows = [Chapter]()
        var taken = Set<ObjectIdentifier>()
        var materialized = false

        // the generated intro/outro have no row and don't move, see `inPlaybackOrder`
        for chapter in chapters where !chapter.isIntro && !chapter.isOutro {
            var row: Chapter? = chapter.persistentId.flatMap { context.existingModel(for: $0) }
            if row == nil {
                if !materialized {
                    // nothing has edited this video yet: one pass turns its whole derived set into rows
                    reconcileChapters(video.ownChapterData, for: video)
                    invalidateDerivedChapters(youtubeId: video.youtubeId)
                    materialized = true
                }
                row = unclaimedRow(for: chapter, of: video, taken: taken)
            }
            guard let row, taken.insert(ObjectIdentifier(row)).inserted else {
                Log.warning("setChapterOrder: no row for \(chapter)")
                continue
            }
            rows.append(row)
        }

        for (index, row) in rows.enumerated() where row.order != index {
            row.order = index
        }
        video.chaptersDidChange()
        try? context.save()

        notifyPlayer(of: video)
    }

    /// A chapter the user dragged carries no row of its own; `taken` keeps two of them that look
    /// alike from claiming the same one.
    @MainActor
    private static func unclaimedRow(
        for chapter: SendableChapter,
        of video: Video,
        taken: Set<ObjectIdentifier>
    ) -> Chapter? {
        let candidates = (video.chapters ?? []).filter { !taken.contains(ObjectIdentifier($0)) }
        // by title where the start times don't line up — a skipped intro shifts the first
        // chapter's start, and the derived chapter the user dragged carries the shifted one
        return candidates.first { $0.startTime == chapter.startTime }
            ?? candidates.first { $0.title != nil && $0.title == chapter.title }
    }

    /// Drops a custom chapter order, leaving everything else about the chapters alone.
    @MainActor
    static func resetChapterOrder(for video: Video) {
        guard let context = video.modelContext else {
            Log.warning("resetChapterOrder: video has no context")
            return
        }
        clearChapterOrder(of: video)
        video.chaptersDidChange()
        try? context.save()

        notifyPlayer(of: video)
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
        allowPodcastChapterRefetch(youtubeId: video.youtubeId)
        video.chaptersDidChange()
        try? context.save()

        notifyPlayer(of: video, refresh: true)
    }
}
