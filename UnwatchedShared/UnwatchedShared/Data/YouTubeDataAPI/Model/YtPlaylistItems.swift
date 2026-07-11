//
//  YtPlaylistItems.swift
//  UnwatchedShared
//

import Foundation

public struct YtPlaylistItems: Codable {

    public struct ContentDetails: Codable {
        let videoId: String
    }

    public struct Item: Codable {
        let snippet: YtVideoSnippet
        let contentDetails: ContentDetails
    }

    public struct PageInfo: Codable {
        let totalResults: Int
        let resultsPerPage: Int
    }

    let items: [Item]
    let pageInfo: PageInfo
    let nextPageToken: String?
}
