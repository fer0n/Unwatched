//
//  VideoActor+WatchLater.swift
//  Unwatched
//

import SwiftData
import UnwatchedShared

extension VideoActor {
    /// Watch Later has no feed, only the signed-in youtube.com page.
    func fetchWatchLater(_ sub: SendableSubscription) async -> FetchResult {
        guard !skipWatchLater else {
            return FetchResult(sub: sub, videos: [], errorMessage: nil)
        }
        do {
            let videos = try await Self.loadWatchLater()
            Log.refresh.info("watch later: \(videos.count) videos")
            return FetchResult(sub: sub, videos: videos.map(SearchVM.sendable), errorMessage: nil)
        } catch {
            Log.refresh.error("watch later: \(error)")
            return FetchResult(sub: sub, videos: [], errorMessage: error.localizedDescription)
        }
    }

    static func loadWatchLater() async throws -> [ITVideo] {
        var videos = [ITVideo]()
        var token: String?
        for _ in 0..<Const.watchLaterRefreshPages {
            let page = try await HomeFeedService.shared.fetchPlaylist(
                YoutubeUrlParser.watchLaterPlaylistId,
                continuationToken: token
            )
            videos += page.videos
            token = page.nextPageToken
            if token == nil { break }
        }
        return videos
    }

    /// Triages by id rather than upload date: saving an old video makes it new to the list.
    func handleWatchLater(
        _ videos: [SendableVideo],
        sub: SendableSubscription,
        _ defaultPlacement: DefaultVideoPlacement
    ) async throws -> FetchedVideoIds {
        guard !videos.isEmpty, let subId = getSubscription(via: sub)?.persistentModelID else {
            return ([], [])
        }
        let seen = WatchLaterState.seenIds()
        var candidates = videos.filter { !seen.contains($0.youtubeId) }
        if seen.isEmpty {
            candidates = Array(candidates.prefix(Const.triageNewSubs(newSubCount: 1)))
        }
        let knownIds = Set(libraryVideos(withIds: candidates.map(\.youtubeId)).map(\.youtubeId))
        let fresh = await addShortsDetectionAndImageData(to: candidates.filter { !knownIds.contains($0.youtubeId) })

        guard let subscription: Subscription = modelContext.resolvedModel(withID: subId) else {
            return ([], [])
        }
        cacheImages(for: fresh, discardShorts: subscription.shortsSetting.shouldHide())
        let inserted = insertVideoModels(from: fresh, to: subscription)
        let known = libraryVideos(withIds: Array(knownIds)).filter { $0.inboxEntry == nil && $0.queueEntry == nil }
        let added = triageSubscriptionVideos(subscription, videos: known + inserted, defaultPlacement: defaultPlacement)
        updateRecentVideoDate(subscription, getMostRecentDate(fresh))
        try modelContext.save()
        WatchLaterState.record(videos.map(\.youtubeId))
        VideoService.fetchMissingInfoInBg(youtubeIds: added.map(\.youtubeId))
        return (inserted.map(\.persistentModelID), added.map(\.persistentModelID))
    }

    /// One row per id, from any subscription
    private func libraryVideos(withIds ids: [String]) -> [Video] {
        guard !ids.isEmpty else { return [] }
        let fetch = FetchDescriptor<Video>(predicate: #Predicate { ids.contains($0.youtubeId) })
        var seen = Set<String>()
        return ((try? modelContext.fetch(fetch)) ?? []).filter { seen.insert($0.youtubeId).inserted }
    }
}
