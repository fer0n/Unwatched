//
//  Tag.swift
//  Unwatched
//

import Foundation
import SwiftData

/// How a tag turns channels into a slice.
public enum TagMode: Int, Codable, Sendable, CaseIterable, Identifiable {
    /// Only the channels the tag holds.
    case include = 0
    /// Everything but the channels the tag holds.
    case exclude = 1
    /// The channels no `include` tag holds. The tag's own channels take no part.
    case untagged = 2

    public var id: Int { rawValue }

    /// What a tag shows before it is given a symbol of its own.
    public var defaultSymbol: String {
        switch self {
        case .include: "tag.fill"
        case .exclude: "tag.slash"
        case .untagged: Const.untaggedSF
        }
    }
}

/// A named slice of the queue: the channels it holds, plus the videos it names on top of them.
@Model
public final class Tag: CustomStringConvertible, Exportable {
    public typealias ExportType = SendableTag

    public var name: String = ""
    public var order: Int = Int.max
    public var createdDate: Date?

    @Relationship(inverse: \Video.tags)
    public var videos: [Video]?

    @Relationship(inverse: \Subscription.tags)
    public var subscriptions: [Subscription]?

    public var symbol: String?

    /// Whether the queue's tag button steps through this tag.
    public var quickSwitch: Bool = true

    /// What continuous play is set to when playback moves into this tag; `nil` leaves the global setting alone.
    public var continuousPlay: Bool?

    /// Whether this tag's videos may be offered as audio suggestions; `nil` follows the global setting.
    public var suggestVideos: Bool?

    /// Raw so a value the app doesn't know reads as `include` instead of failing the store.
    public var _mode: Int? = TagMode.include.rawValue
    public var mode: TagMode {
        get { _mode.flatMap(TagMode.init(rawValue:)) ?? .include }
        set { _mode = newValue.rawValue }
    }

    public init(
        name: String,
        order: Int = Int.max,
        createdDate: Date? = .now,
        symbol: String? = nil,
        quickSwitch: Bool = true,
        mode: TagMode = .include,
        continuousPlay: Bool? = nil,
        suggestVideos: Bool? = nil
    ) {
        self.name = name
        self.order = order
        self.createdDate = createdDate
        self.symbol = symbol
        self.quickSwitch = quickSwitch
        self._mode = mode.rawValue
        self.continuousPlay = continuousPlay
        self.suggestVideos = suggestVideos
    }

    /// The tags a channel or video can be added to.
    public static let includeMode: Predicate<Tag> = {
        let include = TagMode.include.rawValue
        return #Predicate<Tag> { $0._mode == nil || $0._mode == include }
    }()

    public var displaySymbol: String {
        symbol ?? mode.defaultSymbol
    }

    /// What "untagged" measures against: only `include` tags claim what they hold.
    public static func coveredSubscriptions(_ tags: [Tag]) -> [Subscription] {
        covered(tags, \.subscriptions)
    }

    public static func coveredVideos(_ tags: [Tag]) -> [Video] {
        covered(tags, \.videos)
    }

    private static func covered<T>(_ tags: [Tag], _ members: KeyPath<Tag, [T]?>) -> [T] {
        tags.filter { $0.mode == .include }.flatMap { $0[keyPath: members] ?? [] }
    }

    /// The tag whose continuous play setting a video follows.
    public static func continuousPlayTag(for video: Video) -> Tag? {
        decidingTag(for: video, \.continuousPlay)
    }

    /// The tag that decides whether a video is offered as an audio suggestion.
    public static func suggestVideosTag(for video: Video) -> Tag? {
        decidingTag(for: video, \.suggestVideos)
    }

    /// The tag whose opinion on a setting a video follows: the video's own tags before its channel's, lowest order
    /// first.
    private static func decidingTag(for video: Video, _ setting: KeyPath<Tag, Bool?>) -> Tag? {
        ((video.tags ?? []) + (video.subscription?.tags ?? []))
            .filter { $0.mode == .include && $0[keyPath: setting] != nil }
            .min { $0.order < $1.order }
    }

    public func covers(_ subscription: Subscription?) -> Bool {
        holds(subscription, \.subscriptions)
    }

    public func covers(video: Video?) -> Bool {
        holds(video, \.videos)
    }

    public func setCovers(_ subscription: Subscription, _ isCovered: Bool) {
        setHolds(subscription, \.subscriptions, isCovered)
    }

    public func setCovers(video: Video, _ isCovered: Bool) {
        setHolds(video, \.videos, isCovered)
    }

    private func holds<T: PersistentModel>(_ model: T?, _ members: KeyPath<Tag, [T]?>) -> Bool {
        guard let model else { return false }
        return (self[keyPath: members] ?? []).contains { $0.persistentModelID == model.persistentModelID }
    }

    private func setHolds<T: PersistentModel>(
        _ model: T,
        _ members: ReferenceWritableKeyPath<Tag, [T]?>,
        _ isCovered: Bool
    ) {
        var models = (self[keyPath: members] ?? []).filter { $0.persistentModelID != model.persistentModelID }
        if isCovered {
            models.append(model)
        }
        self[keyPath: members] = models
    }

    public var description: String {
        name
    }

    /// Natural keys, not rows: a restored store shares none of the row ids.
    public var toExport: SendableTag? {
        SendableTag(
            name: name,
            order: order,
            createdDate: createdDate,
            subscriptionKeys: (subscriptions ?? []).compactMap(\.subscriptionKey),
            videoIds: (videos ?? []).map(\.youtubeId),
            symbol: symbol,
            quickSwitch: quickSwitch,
            mode: mode.rawValue,
            continuousPlay: continuousPlay,
            suggestVideos: suggestVideos
        )
    }
}
