//
//  VideoActor+FeedFallback.swift
//  Unwatched
//

import SwiftData
import UnwatchedShared

extension VideoActor {
    func handleFallbackIfOutage(
        _ outcomes: [FetchOutcome],
        _ unavailableSubs: [SendableSubscription],
        _ placementInfo: DefaultVideoPlacement
    ) async throws -> (videoInfo: [FetchedVideoIds], recovered: Set<PersistentIdentifier>) {
        guard isYoutubeOutage(outcomes) else { return ([], []) }
        var videoInfo = [FetchedVideoIds]()
        var recovered = Set<PersistentIdentifier>()
        for fetched in await fetchFallbackVideos(unavailableSubs) {
            if let id = fetched.sub.persistentId {
                recovered.insert(id)
            }
            videoInfo.append(try await handleFetched(fetched, placementInfo))
        }
        return (videoInfo, recovered)
    }

    func finishFallback(after fetched: FetchResult) -> FeedFallbackState.CatchUp? {
        guard !fetched.isFallback, fetched.errorMessage == nil, let channelId = fetched.sub.youtubeChannelId else {
            return nil
        }
        return FeedFallbackState.finish(channelId: channelId)
    }

    /// One per channel, and only with a cutoff to triage against.
    private func fetchFallbackVideos(_ unavailableSubs: [SendableSubscription]) async -> [FetchResult] {
        var channelIds = Set<String>()
        let subs = unavailableSubs.filter {
            guard !$0.isPodcast, $0.youtubePlaylistId == nil, $0.mostRecentVideoDate != nil,
                  let channelId = $0.youtubeChannelId else { return false }
            return channelIds.insert(channelId).inserted
        }
        guard !subs.isEmpty else { return [] }
        Log.info("fetchFallbackVideos: \(subs.count) channels via InnerTube")

        let api = InnerTubeAPI()
        var results = [FetchResult]()
        for start in stride(from: 0, to: subs.count, by: Const.feedFallbackConcurrency) {
            let batch = subs[start..<min(start + Const.feedFallbackConcurrency, subs.count)]
            let batchResults = await withTaskGroup(of: FetchResult?.self) { group in
                for sub in batch {
                    group.addTask { await self.loadFallbackVideos(sub, api) }
                }
                return await group.compactMap { $0 }.reduce(into: []) { $0.append($1) }
            }
            results += batchResults
            if batchResults.isEmpty || Task.isCancelled { break }
        }
        Log.info("fetchFallbackVideos: \(results.count)/\(subs.count) channels, \(results.flatMap(\.videos).count) videos")
        return results
    }

    private func loadFallbackVideos(_ sub: SendableSubscription, _ api: InnerTubeAPI) async -> FetchResult? {
        guard let channelId = sub.youtubeChannelId, let cutoff = sub.mostRecentVideoDate else { return nil }
        do {
            var candidates = try await FeedFallbackService.candidates(api, channelId: channelId, after: cutoff)
            let known = existingYoutubeIds(candidates.map(\.id))
                .union(FeedFallbackState.deliveredIds(channelId: channelId))
            candidates.removeAll { known.contains($0.id) }
            let videos = await FeedFallbackService.videos(
                api,
                from: candidates,
                channelId: channelId,
                feedTitle: sub.title,
                after: cutoff
            )
            FeedFallbackState.record(channelId: channelId, cutoff: cutoff, delivered: videos.map(\.youtubeId))
            return FetchResult(sub: sub, videos: videos, errorMessage: nil, isFallback: true)
        } catch {
            Log.warning("loadFallbackVideos failed for \(sub.title): \(error)")
            return nil
        }
    }

    /// Store-wide: a video another subscription holds mustn't get a second row.
    private func existingYoutubeIds(_ youtubeIds: [String]) -> Set<String> {
        guard !youtubeIds.isEmpty else { return [] }
        let fetch = FetchDescriptor<Video>(predicate: #Predicate { youtubeIds.contains($0.youtubeId) })
        return Set((try? modelContext.fetch(fetch))?.map(\.youtubeId) ?? [])
    }
}
