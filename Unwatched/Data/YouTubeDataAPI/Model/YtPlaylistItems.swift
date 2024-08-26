//
//  VideoInfo.swift
//  Unwatched
//

import Foundation

struct YtPlaylistItems: Codable {

    struct ContentDetails: Codable {
        let videoId: String
    }

    struct Item: Codable {
        let snippet: YtVideoSnippet
        let contentDetails: ContentDetails
    }

    struct PageInfo: Codable {
        let totalResults: Int
        let resultsPerPage: Int
    }

    let items: [Item]
    let pageInfo: PageInfo
    let nextPageToken: String?
}
