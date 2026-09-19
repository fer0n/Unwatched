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

    var channel: YoutubeChannelSearchResult? {
        if case .channel(let channel) = self { return channel }
        return nil
    }

    var podcast: SendableSubscription? {
        if case .podcast(let podcast) = self { return podcast }
        return nil
    }

    var isPodcast: Bool {
        podcast != nil
    }

    var id: String {
        switch self {
        case .channel(let channel): "channel-\(channel.channelId)"
        case .podcast(let podcast): "podcast-\(podcast.link?.absoluteString ?? podcast.title)"
        }
    }

    var title: String {
        switch self {
        case .channel(let channel): channel.title
        case .podcast(let podcast): podcast.title
        }
    }

    var thumbnailUrl: URL? {
        switch self {
        case .channel(let channel): channel.thumbnailUrl
        case .podcast(let podcast): podcast.thumbnailUrl
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
        }
    }
}
