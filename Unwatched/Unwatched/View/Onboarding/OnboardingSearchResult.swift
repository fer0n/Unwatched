//
//  OnboardingSearchResult.swift
//  Unwatched
//

import Foundation
import UnwatchedShared

/// A single result in the onboarding search: a YouTube channel or an audio-only podcast.
enum OnboardingSearchResult: Identifiable, Hashable {
    case channel(YoutubeChannelSearchResult)
    case podcast(SendableSubscription)
    case watchLater

    init?(subscription: SendableSubscription) {
        if let channelId = subscription.youtubeChannelId {
            self = .channel(YoutubeChannelSearchResult(
                channelId: channelId,
                title: subscription.title,
                userName: subscription.youtubeUserName,
                thumbnailUrl: subscription.thumbnailUrl
            ))
        } else if subscription.isPodcast {
            self = .podcast(subscription)
        } else {
            return nil
        }
    }

    var channel: YoutubeChannelSearchResult? {
        if case .channel(let channel) = self { return channel }
        return nil
    }

    var podcast: SendableSubscription? {
        if case .podcast(let podcast) = self { return podcast }
        return nil
    }

    var isWatchLater: Bool {
        if case .watchLater = self { true } else { false }
    }

    var isPodcast: Bool {
        podcast != nil
    }

    var id: String {
        switch self {
        case .channel(let channel): "channel-\(channel.channelId)"
        case .podcast(let podcast): "podcast-\(podcast.link?.absoluteString ?? podcast.title)"
        case .watchLater: "watchLater"
        }
    }

    var title: String {
        switch self {
        case .channel(let channel): channel.title
        case .podcast(let podcast): podcast.title
        case .watchLater: String(localized: "watchLater")
        }
    }

    var thumbnailUrl: URL? {
        switch self {
        case .channel(let channel): channel.thumbnailUrl
        case .podcast(let podcast): podcast.thumbnailUrl
        case .watchLater: nil
        }
    }

    /// Subscriber count or `@handle` for a channel, the show's author for a podcast
    var subtitle: String? {
        switch self {
        case .channel(let channel):
            [channel.subscriberCount, channel.userName.map { "@\($0)" }]
                .compactMap { $0 }
                .first
        case .podcast(let podcast):
            podcast.author
        case .watchLater:
            nil
        }
    }
}
