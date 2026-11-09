//
//  SearchVM+Link.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

extension SearchVM {
    struct LinkLookup {
        let link: String
        var isLoading = true
        var error: String?
    }

    enum LinkKind {
        case video, channel, playlist, podcast, other

        init(_ link: String) {
            let url = URL(string: link)
            if UrlService.getPlaylistIdFromUrl(link) != nil {
                self = .playlist
            } else if SearchVM.videoUrl(link) != nil {
                self = .video
            } else if let url, UrlService.getChannelIdFromUrl(url) != nil
                        || UrlService.getChannelUserNameFromUrl(url) != nil
                        || UrlService.isYoutubeFeedUrl(url: url) {
                self = .channel
            } else if let url, Self.looksLikePodcast(url) {
                self = .podcast
            } else {
                self = .other
            }
        }

        static func looksLikePodcast(_ url: URL) -> Bool {
            if PodcastSearchService.collectionId(from: url) != nil {
                return true
            }
            let host = url.host()?.lowercased() ?? ""
            guard !host.contains("youtube.com"), !host.contains("youtu.be") else { return false }
            let path = url.path().lowercased()
            return host.hasPrefix("feeds.") || host.hasPrefix("feed.")
                || [".xml", ".rss", "/rss", "/rss/"].contains { path.hasSuffix($0) }
                || url.pathComponents.contains { ["feed", "feeds"].contains($0.lowercased()) }
        }
    }

    private struct LinkError: LocalizedError {
        let errorDescription: String?
    }

    var activeLink: String? {
        UrlService.firstUrl(in: activeQuery)
    }

    nonisolated static func videoUrl(_ link: String) -> URL? {
        guard let url = URL(string: link).map(AppLink.resolving),
              let youtubeId = UrlService.getYoutubeIdFromUrl(url: url) else { return nil }
        return URL(string: UrlService.getNonEmbeddedYoutubeUrl(youtubeId, UrlService.getStartTimeFromUrl(url)))
    }

    static func cleanPasted(_ text: String?) -> String? {
        guard let text = text?
                .split(whereSeparator: \.isNewline).joined(separator: " ")
                .trimmingCharacters(in: .whitespaces),
              !text.isEmpty else { return nil }
        return text
    }

    @discardableResult
    func openLinkIfPresent(in text: String, _ navManager: NavigationManager) -> Bool {
        guard let link = UrlService.firstUrl(in: text) else { return false }
        showsYoutube = false
        query = text
        search()
        linkTask?.cancel()
        linkLookup = LinkLookup(link: link)
        linkTask = Task {
            do {
                let route = try await Self.route(for: link)
                try Task.checkCancellation()
                navManager.presentedSearch.append(route)
                linkLookup = nil
            } catch {
                guard !Task.isCancelled else { return }
                linkLookup?.isLoading = false
                linkLookup?.error = error.localizedDescription
            }
        }
        return true
    }

    func cancelLinkLookup() {
        linkTask?.cancel()
        linkLookup = nil
    }

    /// Links can carry private feed tokens, so they skip the search services.
    func showLinkOnly() {
        podcastTask?.cancel()
        localTask?.cancel()
        withAnimation {
            podcastResults = []
            localResults = LocalSearchResults()
        }
        resetYoutubeResults()
    }

    func resetYoutubeResults() {
        withAnimation {
            results = []
        }
        nextPageToken = nil
        isSearching = false
        isLoadingMore = false
    }

    private static func route(for link: String) async throws -> SearchRoute {
        guard let url = URL(string: link) else { throw SubscriptionError.notAnUrl(link) }
        if LinkKind(link) != .playlist, let videoUrl = videoUrl(link) {
            try Task.checkCancellation()
            guard let video = try await VideoService.importFirst(videoUrl, in: nil) else {
                throw SubscriptionError.failedGettingVideoInfo
            }
            return .video(VideoDetailRoute(video))
        }
        let (state, sub) = await SubscriptionService.loadSubscriptionInfo(url)
        if let id = state.subscriptionId,
           let existing = DataProvider.mainContext.existingModel(for: id) as Subscription?,
           let export = existing.toExport {
            return .subscription(export)
        }
        if let sub {
            return .subscription(sub)
        }
        let message = state.error ?? SubscriptionError.noInfoFoundToSubscribeTo.localizedDescription
        throw LinkError(errorDescription: message)
    }
}
