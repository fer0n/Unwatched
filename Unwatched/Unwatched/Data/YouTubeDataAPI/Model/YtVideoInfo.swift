//
//  VideoInfo.swift
//  Unwatched
//

import Foundation

struct YtVideoInfo: Codable {

    struct ContentDetails: Codable {
        let duration: String
    }

    struct Item: Codable {
        let snippet: YtVideoSnippet
        let contentDetails: ContentDetails
    }

    let items: [Item]
}

struct YtVideoSnippet: Codable {
    struct High: Codable {
        let url: String
    }

    struct Thumbnails: Codable {
        let high: High?
    }

    let title: String
    let thumbnails: Thumbnails
    let channelTitle: String
    let channelId: String
    let publishedAt: String
    let description: String
}
