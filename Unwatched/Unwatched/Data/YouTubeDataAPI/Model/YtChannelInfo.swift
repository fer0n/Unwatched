//
//  YtChannelInfo.swift
//  Unwatched
//

import Foundation

struct YtChannelInfo: Decodable {
    // swiftlint:disable:next type_name
    struct Id: Decodable {
        let channelId: String
    }

    struct Items: Decodable {
        let id: Id
    }

    let items: [Items]
}
