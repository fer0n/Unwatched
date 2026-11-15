//
//  Tag.swift
//  Unwatched
//

import Foundation
import SwiftData

/// How a tag turns channels into a slice.
@frozen public enum TagMode: Int, Codable, Sendable, CaseIterable, Identifiable {
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

@frozen public enum TagPodcasts: Int, Codable, Sendable, CaseIterable, Identifiable {
    case listed = 0
    case all = 1
    case hidden = 2

    public var id: Int { rawValue }
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

    /// Videos of the tag's channels taken back out. Only `include` tags have any.
    @Relationship(inverse: \Video.excludedFromTags)
    public var excludedVideos: [Video]?

    public var symbol: String?

    /// Whether the queue's tag button steps through this tag.
    public var quickSwitch: Bool = true

    /// What continuous play is set to when playback moves into this tag; `nil` leaves the global setting alone.
    public var continuousPlay: Bool?

    /// Whether this tag's videos may be offered as audio suggestions; `nil` follows the global setting.
    public var suggestVideos: Bool?

    /// How far a seek moves within this tag's videos; `nil` follows the global setting.
    public var seekSeconds: Double?

    /// The speed this tag's videos play at; `nil` follows the global setting.
    public var playbackSpeed: Double?

    /// Raw `PlayerTypeSetting`; `nil` follows the global setting.
    public var _playerType: String?
    public var playerType: PlayerTypeSetting? {
        get { _playerType.flatMap(PlayerTypeSetting.init(rawValue:)) }
        set { _playerType = newValue?.rawValue }
    }

    /// Raw so a value the app doesn't know reads as `include` instead of failing the store.
    public var _mode: Int? = TagMode.include.rawValue
    public var mode: TagMode {
        get { _mode.flatMap(TagMode.init(rawValue:)) ?? .include }
        set { _mode = newValue.rawValue }
    }

    public var _podcasts: Int? = TagPodcasts.listed.rawValue
    public var podcasts: TagPodcasts {
        get { _podcasts.flatMap(TagPodcasts.init(rawValue:)) ?? .listed }
        set { _podcasts = newValue.rawValue }
    }

    public init(
        name: String,
        order: Int = Int.max,
        createdDate: Date? = .now,
        symbol: String? = nil,
        quickSwitch: Bool = false,
        mode: TagMode = .include,
        podcasts: TagPodcasts = .listed,
        continuousPlay: Bool? = nil,
        suggestVideos: Bool? = nil,
        seekSeconds: Double? = nil,
        playbackSpeed: Double? = nil,
        playerType: PlayerTypeSetting? = nil
    ) {
        self.name = name
        self.order = order
        self.createdDate = createdDate
        self.symbol = symbol
        self.quickSwitch = quickSwitch
        self._mode = mode.rawValue
        self._podcasts = podcasts.rawValue
        self.continuousPlay = continuousPlay
        self.suggestVideos = suggestVideos
        self.seekSeconds = seekSeconds
        self.playbackSpeed = playbackSpeed
        self._playerType = playerType?.rawValue
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
        covered(tags, \.subscriptions, isPodcast: \.isPodcast)
    }

    public static func coveredVideos(_ tags: [Tag]) -> [Video] {
        covered(tags, \.videos, isPodcast: \.isPodcast)
    }

    /// Excluded videos no `include` tag still claims: `untagged` lists them again.
    public static func releasedVideos(_ tags: [Tag]) -> [Video] {
        let including = tags.filter { $0.mode == .include }
        let excluded = including.flatMap { $0.excludedVideos ?? [] }
        guard !excluded.isEmpty else { return [] }
        let claims = including.map(Claims.init)
        let unique = Dictionary(excluded.map { ($0.persistentModelID, $0) }, uniquingKeysWith: { first, _ in first })
        return unique.values.filter { video in !claims.contains { $0.claims(video) } }
    }

    /// A tag's membership as id sets, for checking many videos against it.
    private struct Claims {
        let hidesPodcasts: Bool
        let subscriptionIds: Set<PersistentIdentifier>
        let videoIds: Set<PersistentIdentifier>
        let excludedIds: Set<PersistentIdentifier>

        init(_ tag: Tag) {
            hidesPodcasts = tag.podcasts == .hidden
            subscriptionIds = Set((tag.subscriptions ?? []).map(\.persistentModelID))
            videoIds = Set((tag.videos ?? []).map(\.persistentModelID))
            excludedIds = Set((tag.excludedVideos ?? []).map(\.persistentModelID))
        }

        func claims(_ video: Video) -> Bool {
            guard !hidesPodcasts || !video.isPodcast else { return false }
            let id = video.persistentModelID
            if videoIds.contains(id) { return true }
            guard let subscriptionId = video.subscription?.persistentModelID else { return false }
            return subscriptionIds.contains(subscriptionId) && !excludedIds.contains(id)
        }
    }

    private static func covered<T>(_ tags: [Tag], _ members: KeyPath<Tag, [T]?>, isPodcast: KeyPath<T, Bool>) -> [T] {
        tags.filter { $0.mode == .include }.flatMap { tag in
            (tag[keyPath: members] ?? []).filter { tag.podcasts != .hidden || !$0[keyPath: isPodcast] }
        }
    }

    public func effectivePodcasts(in tags: [Tag]) -> TagPodcasts {
        let anotherTagHasAll = tags.contains { $0.mode == .include && $0.podcasts == .all }
        return podcasts == .listed && mode == .untagged && anotherTagHasAll ? .hidden : podcasts
    }

    /// The tag whose continuous play setting a video follows.
    public static func continuousPlayTag(for video: Video) -> Tag? {
        decidingTag(for: video, \.continuousPlay)
    }

    /// The tag that decides whether a video is offered as an audio suggestion.
    public static func suggestVideosTag(for video: Video) -> Tag? {
        decidingTag(for: video, \.suggestVideos)
    }

    /// The tag whose seek duration a video follows.
    public static func seekSecondsTag(for video: Video) -> Tag? {
        decidingTag(for: video, \.seekSeconds)
    }

    /// The tag whose playback speed a video follows.
    public static func playbackSpeedTag(for video: Video) -> Tag? {
        decidingTag(for: video, \.playbackSpeed)
    }

    /// The tag whose player type a video follows.
    public static func playerTypeTag(for video: Video) -> Tag? {
        decidingTag(for: video, \.playerType)
    }

    /// The tag the player's tag speed lock writes to: the one whose speed is in effect, otherwise the one that would
    /// decide once it had a speed.
    public static func speedLockTag(for video: Video) -> Tag? {
        playbackSpeedTag(for: video) ?? decidingTags(for: video).min { $0.order < $1.order }
    }

    /// The tag whose opinion on a setting a video follows: the video's own tags before its channel's, lowest order
    /// first.
    private static func decidingTag<Value>(for video: Video, _ setting: KeyPath<Tag, Value?>) -> Tag? {
        decidingTags(for: video)
            .filter { $0[keyPath: setting] != nil }
            .min { $0.order < $1.order }
    }

    private static func decidingTags(for video: Video) -> [Tag] {
        let isEpisode = video.isPodcast
        let excluded = Set((video.excludedFromTags ?? []).map(\.persistentModelID))
        let viaChannel = (video.subscription?.tags ?? []).filter { !excluded.contains($0.persistentModelID) }
        let listing = ((video.tags ?? []) + viaChannel)
            .filter { $0.mode == .include && (!isEpisode || $0.podcasts == .listed) }
        guard isEpisode || listing.isEmpty else { return listing }

        let tags = fetchTags(for: video)
        let claiming = isEpisode ? listing + tags.filter { $0.mode == .include && $0.podcasts == .all } : listing
        guard claiming.isEmpty else { return claiming }
        return tags.filter { $0.mode == .untagged && !(isEpisode && $0.podcasts == .hidden) }
    }

    /// Fetched rather than read off the video: a tag that holds nothing of its own is not reachable through the
    /// video's relationships.
    private static func fetchTags(for video: Video) -> [Tag] {
        guard let context = video.modelContext else { return [] }
        return (try? context.fetch(FetchDescriptor<Tag>())) ?? []
    }

    public func covers(_ subscription: Subscription?) -> Bool {
        holds(subscription, \.subscriptions)
    }

    public func covers(video: Video?) -> Bool {
        holds(video, \.videos)
    }

    public func excludes(_ video: Video?) -> Bool {
        holds(video, \.excludedVideos)
    }

    public func contains(_ video: Video?) -> Bool {
        covers(video: video) || (covers(video?.subscription) && !excludes(video))
    }

    /// A channel video is excluded rather than named.
    public func setContains(_ video: Video, _ isContained: Bool) {
        let viaChannel = covers(video.subscription)
        setHolds(video, \.videos, isContained && !viaChannel)
        setHolds(video, \.excludedVideos, !isContained && viaChannel)
    }

    /// Taking a channel out also drops its videos' exclusions, so adding it back starts clean.
    public func setCovers(_ subscription: Subscription, _ isCovered: Bool) {
        setHolds(subscription, \.subscriptions, isCovered)
        if !isCovered, let excluded = excludedVideos,
           excluded.contains(where: { $0.subscription?.persistentModelID == subscription.persistentModelID }) {
            excludedVideos = excluded.filter { $0.subscription?.persistentModelID != subscription.persistentModelID }
        }
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
        guard holds(model, members) != isCovered else { return }
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
            excludedVideoIds: (excludedVideos ?? []).map(\.youtubeId),
            symbol: symbol,
            quickSwitch: quickSwitch,
            mode: mode.rawValue,
            podcasts: podcasts.rawValue,
            continuousPlay: continuousPlay,
            suggestVideos: suggestVideos,
            seekSeconds: seekSeconds,
            playbackSpeed: playbackSpeed,
            playerType: _playerType
        )
    }
}

public extension Video {
    /// The speed that overrides the device default: the channel's own, then the tag's.
    var customPlaybackSpeed: Double? {
        settingsSubscription?.customSpeedSetting ?? Tag.playbackSpeedTag(for: self)?.playbackSpeed
    }

    /// Writes to the override in effect; `false` when there is none.
    func updateCustomPlaybackSpeed(_ value: Double) -> Bool {
        if let subscription = settingsSubscription, subscription.customSpeedSetting != nil {
            subscription.customSpeedSetting = value
        } else if let tag = Tag.playbackSpeedTag(for: self) {
            tag.playbackSpeed = value
        } else {
            return false
        }
        return true
    }
}
