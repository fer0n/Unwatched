//
//  DescriptionLinkTarget.swift
//  UnwatchedShared
//

import Foundation

public enum DescriptionLinkTarget: Sendable {
    case video
    case subscription

    public init?(_ url: URL) {
        if YoutubeUrlParser.getYoutubeId(from: url) != nil || PodcastSearchService.episodeTrackId(from: url) != nil {
            self = .video
        } else if YoutubeUrlParser.isChannelUrl(url) || PodcastSearchService.collectionId(from: url) != nil {
            self = .subscription
        } else {
            return nil
        }
    }
}
