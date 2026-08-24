//
//  SendableTag.swift
//  UnwatchedShared
//

import Foundation

public struct SendableTag: Sendable, Codable, Hashable {
    public var name: String
    public var order: Int
    public var createdDate: Date?
    public var subscriptionKeys: [String]

    /// Optional so a backup written before videos could be tagged still decodes.
    public var videoIds: [String]?

    public var symbol: String?

    /// Optional so a backup written before the setting existed still decodes; `nil` reads as on.
    public var quickSwitch: Bool?

    /// Raw and optional so an unknown mode doesn't fail the whole decode.
    public var mode: Int?

    /// `nil` means the tag has no opinion, see `Tag.continuousPlay`.
    public var continuousPlay: Bool?

    /// `nil` means the tag has no opinion, see `Tag.suggestVideos`.
    public var suggestVideos: Bool?

    public init(
        name: String,
        order: Int = Int.max,
        createdDate: Date? = nil,
        subscriptionKeys: [String] = [],
        videoIds: [String]? = nil,
        symbol: String? = nil,
        quickSwitch: Bool? = nil,
        mode: Int? = nil,
        continuousPlay: Bool? = nil,
        suggestVideos: Bool? = nil
    ) {
        self.name = name
        self.order = order
        self.createdDate = createdDate
        self.subscriptionKeys = subscriptionKeys
        self.videoIds = videoIds
        self.symbol = symbol
        self.quickSwitch = quickSwitch
        self.mode = mode
        self.continuousPlay = continuousPlay
        self.suggestVideos = suggestVideos
    }

    /// Membership is re-linked by `UserDataService`, once the rows it names exist.
    public var toModel: Tag {
        Tag(
            name: name,
            order: order,
            createdDate: createdDate,
            symbol: symbol,
            quickSwitch: quickSwitch ?? true,
            mode: mode.flatMap(TagMode.init(rawValue:)) ?? .include,
            continuousPlay: continuousPlay,
            suggestVideos: suggestVideos
        )
    }
}
