//
//  ShareSubscribeActor.swift
//  UnwatchedShared
//
//  A trimmed-down counterpart to the main app's SubscriptionActor, scoped to exactly what the
//  Share Extension needs: preview, subscribe to, and unsubscribe from a channel/user/playlist
//  URL. Skips InnerTube avatar enrichment (main-app-only, cosmetic) — a subscription added this
//  way just shows a placeholder thumbnail until the next full sync from the main app fills it in.
//

import Foundation
import SwiftData
import OSLog

/// What's known about a shared channel/playlist link, whether or not it's subscribed yet.
public struct ChannelPreview: Sendable {
    public let subscription: SendableSubscription
    public let isSubscribed: Bool
}

@ModelActor
public actor ShareSubscribeActor {
    /// Subscribes to the channel/user/playlist a shared URL points at. Returns the
    /// subscription's title (existing or newly created) so the caller can confirm it.
    public func subscribe(to url: URL) async throws -> String {
        let channelId = YoutubeUrlParser.getChannelId(from: url)
        let userName = YoutubeUrlParser.getChannelUserName(from: url)
        let playlistId = YoutubeUrlParser.getPlaylistId(from: url)

        if let title = unarchive(channelId: channelId, userName: userName, playlistId: playlistId) {
            return title
        }

        let feedUrl = try await resolveFeedUrl(
            url: url,
            channelId: channelId,
            userName: userName,
            playlistId: playlistId
        )
        let sendableSub = try await VideoCrawler.loadSubscriptionFromRSS(feedUrl: feedUrl)

        if let resolvedChannelId = sendableSub.youtubeChannelId,
           let title = unarchive(channelId: resolvedChannelId, userName: nil, playlistId: playlistId) {
            return title
        }

        let sub = sendableSub.createSubscription()
        modelContext.insert(sub)
        try modelContext.save()
        return sub.title
    }

    /// Archives the subscription a shared URL points at, if one exists.
    public func unsubscribe(url: URL) {
        let channelId = YoutubeUrlParser.getChannelId(from: url)
        let userName = YoutubeUrlParser.getChannelUserName(from: url)
        let playlistId = YoutubeUrlParser.getPlaylistId(from: url)
        guard let sub = fetchExisting(channelId: channelId, userName: userName, playlistId: playlistId) else { return }
        sub.isArchived = true
        try? modelContext.save()
    }

    /// What's known about a shared channel/playlist link, without subscribing to it: an existing
    /// subscription's real data if there is one, otherwise a best-effort RSS fetch (name only —
    /// a thumbnail requires InnerTube, which is main-app-only). Returns nil if neither works out.
    public func preview(url: URL) async -> ChannelPreview? {
        let channelId = YoutubeUrlParser.getChannelId(from: url)
        let userName = YoutubeUrlParser.getChannelUserName(from: url)
        let playlistId = YoutubeUrlParser.getPlaylistId(from: url)

        if let preview = existingPreview(channelId: channelId, userName: userName, playlistId: playlistId) {
            return preview
        }

        guard let feedUrl = try? await resolveFeedUrl(
            url: url,
            channelId: channelId,
            userName: userName,
            playlistId: playlistId
        ), let sendableSub = try? await VideoCrawler.loadSubscriptionFromRSS(feedUrl: feedUrl) else {
            return nil
        }

        // Username-based URLs (`/@name`) don't resolve to a channelId until the RSS feed is
        // fetched — existing subscriptions are keyed by that canonical ID (see `subscribe(to:)`),
        // so retry the lookup with it before concluding this channel isn't subscribed yet.
        if let resolvedChannelId = sendableSub.youtubeChannelId,
           let preview = existingPreview(channelId: resolvedChannelId, userName: nil, playlistId: playlistId) {
            return preview
        }

        return ChannelPreview(subscription: sendableSub, isSubscribed: false)
    }

    private func existingPreview(channelId: String?, userName: String?, playlistId: String?) -> ChannelPreview? {
        guard let existing = fetchExisting(channelId: channelId, userName: userName, playlistId: playlistId),
              let export = existing.toExport else {
            return nil
        }
        return ChannelPreview(subscription: export, isSubscribed: !existing.isArchived)
    }

    private func resolveFeedUrl(
        url: URL,
        channelId: String?,
        userName: String?,
        playlistId: String?
    ) async throws -> URL {
        if YoutubeUrlParser.isFeedUrl(url) {
            return url
        }
        if let playlistId, let feedUrl = try? YoutubeUrlParser.getFeedUrl(fromPlaylistId: playlistId) {
            return feedUrl
        }
        if let channelId {
            return try YoutubeUrlParser.getFeedUrl(fromChannelId: channelId)
        }
        guard let userName else {
            throw SubscriptionError.noInfoFoundToSubscribeTo
        }
        let resolvedChannelId = try await YoutubeDataAPI.getYtChannelId(from: userName)
        return try YoutubeUrlParser.getFeedUrl(fromChannelId: resolvedChannelId)
    }

    /// If a matching subscription already exists, unarchives it (or confirms it's already
    /// active) and returns its title. Returns nil when nothing matches, so the caller can
    /// fall through to creating a new subscription.
    private func unarchive(channelId: String?, userName: String?, playlistId: String?) -> String? {
        guard let sub = fetchExisting(channelId: channelId, userName: userName, playlistId: playlistId) else {
            return nil
        }
        sub.isArchived = false
        sub.subscribedDate = .now
        try? modelContext.save()
        return sub.title
    }

    private func fetchExisting(channelId: String?, userName: String?, playlistId: String?) -> Subscription? {
        guard channelId != nil || userName != nil || playlistId != nil else { return nil }
        var fetch = FetchDescriptor<Subscription>(predicate: #Predicate {
            (playlistId == nil || playlistId == $0.youtubePlaylistId) &&
                ((channelId != nil && channelId == $0.youtubeChannelId) ||
                    (userName != nil && $0.youtubeUserName == userName))
        })
        fetch.fetchLimit = 1
        return try? modelContext.fetch(fetch).first
    }
}
