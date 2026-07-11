//
//  YtChannelId.swift
//  UnwatchedShared
//

import Foundation

public struct YtChannelId: Decodable {
    public struct Item: Decodable {
        var id: String
    }

    var items: [Item]
}
