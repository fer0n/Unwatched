//
//  SearchVM+Local.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// The Search tab's local half: which sources are searched, and matching the query
/// against what's already stored in the app. See `LocalSearchService` for the matching
/// itself.
extension SearchVM {
    /// The YouTube results minus anything already listed in the local sections above,
    /// so a video that's in the library isn't shown twice.
    var youtubeResults: [SendableVideo] {
        let localIds = Set((localResults.bookmarks + localResults.videos).map(\.youtubeId))
        guard !localIds.isEmpty else { return results }
        return results.filter { !localIds.contains($0.youtubeId) }
    }

    /// Channels whose name matches the query closely enough, mined from the video
    /// results themselves — YouTube's InnerTube search is video-only server-side (see
    /// `InnerTubeAPI+Search`), so there's no direct channel search to call. Shown above
    /// the video results in the YouTube section, minus channels already listed as an
    /// added subscription.
    var youtubeChannelResults: [SendableSubscription] {
        guard !activeQuery.isEmpty else { return [] }
        let alreadyAdded = Set(localResults.subscriptions.compactMap(\.youtubeChannelId))
        var seen = Set<String>()
        var channels: [SendableSubscription] = []
        for video in results {
            guard var sub = video.subscription,
                  let channelId = sub.youtubeChannelId,
                  !alreadyAdded.contains(channelId),
                  seen.insert(channelId).inserted,
                  LocalSearchService.matchesQuery(sub.title, query: activeQuery) else { continue }
            sub.thumbnailUrl = channelAvatarURLs[channelId]
            channels.append(sub)
            if channels.count >= Self.maxYoutubeChannelResults { break }
        }
        return channels
    }

    private static var maxYoutubeChannelResults: Int { 2 }

    func loadYoutubeChannelAvatarsIfNeeded() {
        let missing = youtubeChannelResults
            .compactMap(\.youtubeChannelId)
            .filter { channelAvatarURLs[$0] == nil }
        guard !missing.isEmpty else { return }
        avatarTask?.cancel()
        avatarTask = Task {
            for channelId in missing {
                if Task.isCancelled { return }
                guard let url = try? await api.fetchChannelAvatarURL(channelId: channelId) else { continue }
                if Task.isCancelled { return }
                channelAvatarURLs[channelId] = url
            }
        }
    }

    func isEnabled(_ source: SearchSource) -> Bool {
        enabledSources.contains(source)
    }

    func setEnabled(_ source: SearchSource, _ isEnabled: Bool) {
        guard self.isEnabled(source) != isEnabled else { return }
        if isEnabled {
            enabledSources.insert(source)
        } else {
            enabledSources.remove(source)
        }
        SearchSource.persistEnabled(enabledSources)
        Signal.log(
            "Search.SourceToggled",
            parameters: ["source": source.rawValue, "value": isEnabled ? "On" : "Off"]
        )
        if source == .youtube {
            rerunActiveSearch()
        } else if source == .podcasts {
            searchPodcasts()
        } else {
            // Local sources are matched in the store — no need to hit the API again.
            searchLocal()
        }
    }

    /// Matches the active query against the stored subscriptions/videos. Runs alongside
    /// the (much slower) YouTube request, so local hits show up immediately.
    func searchLocal() {
        localTask?.cancel()
        let query = activeQuery
        let sources = enabledSources.subtracting([.youtube])
        guard !sources.isEmpty else {
            localResults = LocalSearchResults()
            return
        }
        localTask = Task {
            let found = await LocalSearchService.search(query: query, sources: sources)
            if Task.isCancelled || query != activeQuery { return }
            withAnimation {
                localResults = found
            }
        }
    }
}
