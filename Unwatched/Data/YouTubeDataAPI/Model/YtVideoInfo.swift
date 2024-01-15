//
//  VideoInfo.swift
//  Unwatched
//

import Foundation

struct YtVideoInfo: Codable {
    struct Medium: Codable {
        let url: String
    }

    struct Thumbnails: Codable {
        let medium: Medium
    }

    struct Snippet: Codable {
        let title: String
        let thumbnails: Thumbnails
        let channelTitle: String
        let channelId: String
        let publishedAt: String
        let description: String
    }

    struct ContentDetails: Codable {
        let duration: String
    }

    struct Item: Codable {
        let snippet: Snippet
        let contentDetails: ContentDetails
    }

    let items: [Item]
}
