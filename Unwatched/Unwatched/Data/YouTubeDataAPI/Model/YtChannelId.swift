//
//  YtChannelId.swift
//  Unwatched
//

import Foundation

struct YtChannelId: Decodable {
    struct Item: Decodable {
        var id: String
    }

    var items: [Item]
}
