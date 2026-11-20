//
//  SearchVM+Status.swift
//  Unwatched
//

import SwiftData
import SwiftUI
import UnwatchedShared

/// Keeps the Search tab's rows in sync with the store: results start out as plain
/// `SendableVideo`s (nothing is persisted until the user acts on one), so their
/// inbox/queue/watched badges have to be overlaid from what's actually stored.
extension SearchVM {
    /// Refreshes a single result's inbox/queue/watched status from the store after an
    /// action (e.g. adding to the queue). If the video has since been persisted, its
    /// `SendableVideo` is swapped for the stored one so `VideoListItem` shows the badge.
    func refreshStatus(for youtubeId: String) {
        guard let updated = Self.storedStatus(for: youtubeId) else { return }
        apply([youtubeId: updated])
    }

    /// Overlays stored status onto all current results (e.g. items already in the
    /// queue/inbox, or after returning from playback).
    func refreshAllStatuses() {
        let youtubeIds = (results + localResults.bookmarks + localResults.videos + homeFeed).map(\.youtubeId)
        guard !youtubeIds.isEmpty else { return }
        let stored = Self.storedStatuses(for: youtubeIds)
        guard !stored.isEmpty else { return }
        apply(stored)
    }

    /// Swaps in the stored version of every result it has an entry for, across all video lists.
    func apply(_ stored: [String: SendableVideo]) {
        withAnimation {
            if let updated = Self.applying(stored, to: results) {
                results = updated
            }
            if let updated = Self.applying(stored, to: localResults.bookmarks) {
                localResults.bookmarks = updated
            }
            if let updated = Self.applying(stored, to: localResults.videos) {
                localResults.videos = updated
            }
            if let updated = Self.applying(stored, to: homeFeed) {
                homeFeed = updated
            }
        }
    }

    /// `nil` when nothing changed, so untouched lists aren't reassigned (which would
    /// invalidate the views observing them for no reason).
    private static func applying(
        _ stored: [String: SendableVideo],
        to videos: [SendableVideo]
    ) -> [SendableVideo]? {
        var updated = videos
        var didChange = false
        for index in updated.indices {
            if let storedVideo = stored[updated[index].youtubeId] {
                let match = updated[index].withStatus(of: storedVideo)
                guard match != updated[index] else { continue }
                updated[index] = match
                didChange = true
            }
        }
        return didChange ? updated : nil
    }

    private static func storedStatus(for youtubeId: String) -> SendableVideo? {
        let context = DataProvider.mainContext
        guard let video = VideoService.getVideo(for: youtubeId, modelContext: context) else {
            return nil
        }
        return video.toExportWithSubscription ?? video.toExport
    }

    /// Fetches stored status for many videos in a single query, keyed by `youtubeId`.
    static func storedStatuses(for youtubeIds: [String]) -> [String: SendableVideo] {
        let context = DataProvider.mainContext
        let fetch = FetchDescriptor<Video>(predicate: #Predicate { youtubeIds.contains($0.youtubeId) })
        guard let videos = try? context.fetch(fetch) else { return [:] }
        return Dictionary(
            videos.compactMap { video -> (String, SendableVideo)? in
                guard let export = video.toExportWithSubscription ?? video.toExport else { return nil }
                return (video.youtubeId, export)
            },
            uniquingKeysWith: { first, _ in first }
        )
    }
}

extension SearchVM {
    /// Subscribed collaborator first, then archived, else YouTube's first.
    static func preferringKnownChannels(_ videos: [ITVideo]) -> [ITVideo] {
        let ids: [String?] = videos.flatMap { $0.collaborators.map(\.channelId) }
        guard !ids.isEmpty else { return videos }
        let fetch = FetchDescriptor<Subscription>(predicate: #Predicate {
            $0.youtubePlaylistId == nil && ids.contains($0.youtubeChannelId)
        })
        var known: [String: Subscription] = [:]
        for sub in (try? DataProvider.mainContext.fetch(fetch)) ?? [] {
            guard let id = sub.youtubeChannelId, known[id].map({ $0.isArchived }) ?? true else { continue }
            known[id] = sub
        }

        return videos.map { video in
            let matches = video.collaborators.compactMap { collaborator in
                known[collaborator.channelId].map { (collaborator, $0) }
            }
            guard let match = matches.first(where: { !$0.1.isArchived }) ?? matches.first else { return video }
            let (collaborator, sub) = match
            var video = video
            video.channelId = collaborator.channelId
            video.channelTitle = sub.title.isEmpty ? collaborator.title : sub.title
            return video
        }
    }
}

extension SendableVideo {
    /// The stored version, keeping this result's view count
    func withStatus(of stored: SendableVideo) -> SendableVideo {
        var stored = stored
        stored.viewCount = viewCount
        return stored
    }
}
