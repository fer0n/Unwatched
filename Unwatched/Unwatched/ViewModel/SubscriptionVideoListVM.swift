//
//  SubscriptionVideoListVM.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

@Observable @MainActor final class SubscriptionVideoListVM {
    private var fetched: [ITVideo] = []
    private(set) var nextPageToken: String?
    private(set) var isLoading = false
    private(set) var loadFailed = false
    private var referenceDate: Date?

    @ObservationIgnored private var mappedRemoteVideos: [SendableVideo]?
    @ObservationIgnored private let source: Source
    @ObservationIgnored private let title: String

    private static let minNewVideosPerLoad = 10
    private static let maxPagesPerLoad = 4
    private static let maxPagesPerRestart = 20

    enum Source: Equatable {
        case channel(String)
        case playlist(String)

        init?(_ subscription: Subscription) {
            if let playlistId = subscription.youtubePlaylistId {
                self = .playlist(playlistId)
            } else if let channelId = subscription.youtubeChannelId {
                self = .channel(channelId)
            } else {
                return nil
            }
        }

        var cacheKey: String {
            switch self {
            case .channel(let id): "channel:\(id)"
            case .playlist(let id): "playlist:\(id)"
            }
        }
    }

    init(source: Source, title: String) {
        self.source = source
        self.title = title
        if let cached = SubscriptionVideoCache.shared.entry(for: source.cacheKey) {
            fetched = cached.videos
            nextPageToken = cached.nextPageToken
            referenceDate = cached.referenceDate
        }
    }

    var remoteVideos: [SendableVideo] {
        access(keyPath: \.fetched)
        if let mappedRemoteVideos { return mappedRemoteVideos }
        let mapped = fetched.map(sendable)
        mappedRemoteVideos = mapped
        return mapped
    }

    var canLoadMore: Bool {
        referenceDate == nil || nextPageToken != nil || loadFailed
    }

    func loadMore(excluding storedIds: Set<String>) async {
        guard !isLoading else { return }
        isLoading = true
        loadFailed = false

        var known = storedIds.union(fetched.map(\.id))
        var added: [ITVideo] = []
        var token = nextPageToken
        var anchor = referenceDate
        var failed = false
        var pages = 0
        var restarted = false
        do {
            while pages < (restarted ? Self.maxPagesPerRestart : Self.maxPagesPerLoad) {
                guard let page = try await fetchPage(after: token, detectStale: !restarted) else {
                    Log.warning("SubscriptionVideoList: stale continuation, walking again from the first page")
                    token = nil
                    pages = 0
                    restarted = true
                    continue
                }
                pages += 1
                let fetchedAt = Date()
                let pageAnchor = anchor ?? fetchedAt
                anchor = pageAnchor
                token = page.nextPageToken
                for video in page.videos where known.insert(video.id).inserted {
                    let index = fetched.count + added.count
                    added.append(anchored(video, fetchedAt: fetchedAt, anchor: pageAnchor, index: index))
                }
                if added.count >= Self.minNewVideosPerLoad || token == nil { break }
            }
        } catch {
            Log.error("SubscriptionVideoList loadMore failed: \(error)")
            failed = true
        }
        let changed = !added.isEmpty || token != nextPageToken || anchor != referenceDate
        let merged = (fetched + added).sorted {
            ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast)
        }
        // one animated update, or the List inserts the rows without animation
        mappedRemoteVideos = merged.map(sendable)
        withAnimation {
            fetched = merged
            nextPageToken = token
            referenceDate = anchor
            loadFailed = failed
            isLoading = false
        }
        if changed {
            cacheState()
        }
    }

    private func cacheState() {
        guard let referenceDate else { return }
        SubscriptionVideoCache.shared.store(
            .init(videos: fetched, nextPageToken: nextPageToken, referenceDate: referenceDate),
            for: source.cacheKey
        )
    }

    /// nil when a continuation is stale: rejected with a 400, or answered in a shape that reads as empty.
    private func sendable(_ video: ITVideo) -> SendableVideo {
        switch source {
        case .channel:
            var video = video
            video.channelTitle = title
            return SearchVM.sendable(from: video)
        case .playlist(let playlistId):
            var sendable = SearchVM.sendable(from: video)
            sendable.subscription = SendableSubscription(title: title, youtubePlaylistId: playlistId)
            return sendable
        }
    }

    private func fetchPage(after token: String?, detectStale: Bool) async throws -> InnerTubeAPI.SearchPage? {
        let detectStale = detectStale && token != nil
        do {
            let page = try await fetchPage(after: token)
            return detectStale && page.videos.isEmpty ? nil : page
        } catch APIError.httpError(400) where detectStale {
            return nil
        }
    }

    private func fetchPage(after token: String?) async throws -> InnerTubeAPI.SearchPage {
        let api = InnerTubeAPI()
        return switch source {
        case .channel(let channelId):
            try await api.fetchChannelVideos(channelId: channelId, continuationToken: token)
        case .playlist(let playlistId):
            try await api.fetchPlaylistVideos(playlistId: playlistId, continuationToken: token)
        }
    }

    /// Relative dates in whole seconds from the first load's clock, fetch order breaking ties, so
    /// they're unique and sort the same once stored.
    private func anchored(_ video: ITVideo, fetchedAt: Date, anchor: Date, index: Int) -> ITVideo {
        var video = video
        if let publishedAt = video.publishedAt {
            let age = fetchedAt.timeIntervalSince(publishedAt).rounded()
            video.publishedAt = anchor.addingTimeInterval(-age - Double(index) / 1000)
        }
        return video
    }
}
