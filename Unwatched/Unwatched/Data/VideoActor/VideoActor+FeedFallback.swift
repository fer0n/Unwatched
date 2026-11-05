//
//  VideoActor+FeedFallback.swift
//  Unwatched
//

import SwiftData
import UnwatchedShared

extension VideoActor {
    func handleFeedFallback(
        _ outcomes: [FetchOutcome],
        _ unavailableSubs: [SendableSubscription],
        _ placementInfo: DefaultVideoPlacement
    ) async throws -> (videoInfo: [FetchedVideoIds], recovered: Set<PersistentIdentifier>) {
        let subs = Self.fallbackSubs(unavailableSubs, isOutage: isYoutubeOutage(outcomes))
        guard !subs.isEmpty else { return ([], []) }
        var videoInfo = [FetchedVideoIds]()
        var recovered = Set<PersistentIdentifier>()
        for fetched in await fetchFallbackVideos(subs) {
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

    /// One per channel. Outside an outage, only new subscriptions that never loaded.
    static func fallbackSubs(_ unavailableSubs: [SendableSubscription], isOutage: Bool) -> [SendableSubscription] {
        var channelIds = Set<String>()
        return unavailableSubs.filter {
            guard !$0.isPodcast, $0.youtubePlaylistId == nil,
                  isOutage || $0.isNewAndNeverLoaded,
                  let channelId = $0.youtubeChannelId else { return false }
            return channelIds.insert(channelId).inserted
        }
    }

    private func fetchFallbackVideos(_ subs: [SendableSubscription]) async -> [FetchResult] {
        Log.refresh.info("fetchFallbackVideos: \(subs.count) channels via InnerTube")

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
        Log.refresh.info("fetchFallbackVideos: \(results.count)/\(subs.count) channels, \(results.flatMap(\.videos).count) videos")
        return results
    }

    private func loadFallbackVideos(_ sub: SendableSubscription, _ api: InnerTubeAPI) async -> FetchResult? {
        guard let channelId = sub.youtubeChannelId else { return nil }
        let cutoff = sub.mostRecentVideoDate ?? .distantPast
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
            Self.recordFallback(sub, channelId: channelId, delivered: videos)
            return FetchResult(sub: sub, videos: videos, errorMessage: nil, isFallback: true)
        } catch {
            Log.refresh.warning("loadFallbackVideos failed for \(sub.title): \(error)")
            return nil
        }
    }

    /// Unrecorded, a never-loaded subscription gets a regular first load once RSS is back.
    static func recordFallback(_ sub: SendableSubscription, channelId: String, delivered: [SendableVideo]) {
        guard let cutoff = sub.mostRecentVideoDate ?? firstLoadCutoff(sub, delivered) else { return }
        FeedFallbackState.record(channelId: channelId, cutoff: cutoff, delivered: delivered.map(\.youtubeId))
    }

    private static func firstLoadCutoff(_ sub: SendableSubscription, _ delivered: [SendableVideo]) -> Date? {
        guard let newest = delivered.compactMap(\.publishedDate).max() else { return nil }
        return max(newest, sub.subscribedDate ?? .now)
    }

    /// Store-wide: a video another subscription holds mustn't get a second row.
    private func existingYoutubeIds(_ youtubeIds: [String]) -> Set<String> {
        guard !youtubeIds.isEmpty else { return [] }
        let fetch = FetchDescriptor<Video>(predicate: #Predicate { youtubeIds.contains($0.youtubeId) })
        return Set((try? modelContext.fetch(fetch))?.map(\.youtubeId) ?? [])
    }
}

private extension SendableSubscription {
    static let newSubscriptionWindow: TimeInterval = 7 * 24 * 60 * 60

    var isNewAndNeverLoaded: Bool {
        mostRecentVideoDate == nil
            && (subscribedDate ?? .distantPast) > .now.addingTimeInterval(-Self.newSubscriptionWindow)
    }
}
