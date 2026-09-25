//
//  WatchRemote.swift
//  UnwatchedShared
//

import Foundation

/// What the phone is playing. Position is a reading plus the moment it was taken, so the watch can
/// carry the timeline forward on its own.
public struct WatchRemoteState: WatchPayload {
    public var isPlaying: Bool
    public var title: String?
    public var channelTitle: String?
    public var thumbnailUrl: URL?
    public var isAudioOnly: Bool
    public var duration: Double?
    public var position: Double
    public var positionDate: Date
    public var speed: Double
    public var hasCustomSpeed: Bool
    public var canSetCustomSpeed: Bool
    /// The tag a speed lock writes to, see `Tag.speedLockTag`; `nil` when no tag could decide. Optional, like
    /// `hasTagSpeed`, so an older context still decodes.
    public var speedLockTagName: String?
    public var hasTagSpeed: Bool?
    public var hasPreviousChapter: Bool
    public var hasNextChapter: Bool
    public var chapterTitle: String?
    public var chapterEndTime: Double?
    public var continuousPlay: Bool
    public var trimSilence: Bool
    public var canTrimSilence: Bool
    /// `ThemeColor.rawValue`, which syncs nowhere else. Optional so an older context still decodes.
    public var theme: Int?
    /// How far a seek moves in what is playing, where a tag decided; `nil` leaves the watch its
    /// own defaults. Sent so the watch's buttons and the seek the phone performs are one number.
    public var seekSeconds: Double?

    public init(
        isPlaying: Bool,
        title: String? = nil,
        channelTitle: String? = nil,
        thumbnailUrl: URL? = nil,
        isAudioOnly: Bool = false,
        duration: Double? = nil,
        position: Double = 0,
        positionDate: Date = .now,
        speed: Double = 1,
        hasCustomSpeed: Bool = false,
        canSetCustomSpeed: Bool = false,
        speedLockTagName: String? = nil,
        hasTagSpeed: Bool? = nil,
        hasPreviousChapter: Bool = false,
        hasNextChapter: Bool = false,
        chapterTitle: String? = nil,
        chapterEndTime: Double? = nil,
        continuousPlay: Bool = false,
        trimSilence: Bool = false,
        canTrimSilence: Bool = false,
        theme: Int? = nil,
        seekSeconds: Double? = nil
    ) {
        self.isPlaying = isPlaying
        self.title = title
        self.channelTitle = channelTitle
        self.thumbnailUrl = thumbnailUrl
        self.isAudioOnly = isAudioOnly
        self.duration = duration
        self.positionDate = positionDate
        self.position = position
        self.speed = speed
        self.hasCustomSpeed = hasCustomSpeed
        self.canSetCustomSpeed = canSetCustomSpeed
        self.speedLockTagName = speedLockTagName
        self.hasTagSpeed = hasTagSpeed
        self.hasPreviousChapter = hasPreviousChapter
        self.hasNextChapter = hasNextChapter
        self.chapterTitle = chapterTitle
        self.chapterEndTime = chapterEndTime
        self.continuousPlay = continuousPlay
        self.trimSilence = trimSilence
        self.canTrimSilence = canTrimSilence
        self.theme = theme
        self.seekSeconds = seekSeconds
    }

    public var themeColor: ThemeColor {
        theme.flatMap(ThemeColor.init(rawValue:)) ?? .defaultTheme
    }

    /// What is left of the chapter, or of the item when it has none.
    public func remaining(at date: Date = .now) -> Double? {
        guard let end = chapterEndTime ?? duration else { return nil }
        return max(0, end - position(at: date))
    }

    public var hasChapters: Bool {
        hasPreviousChapter || hasNextChapter
    }

    public var isEmpty: Bool {
        title == nil
    }

    public func position(at date: Date = .now) -> Double {
        guard isPlaying else { return position }
        let carried = position + date.timeIntervalSince(positionDate) * speed
        guard let duration else { return max(0, carried) }
        return min(duration, max(0, carried))
    }

    public static let payloadKey = "watchRemoteState"
    public static let requestKey = "watchRemoteStateRequest"
}

@frozen public enum WatchRemoteCommand: WatchPayload {
    case togglePlay
    case play(String)
    case seek(Double)
    case setSpeed(Double)
    case setCustomSpeed(Bool)
    case setTagSpeed(Bool)
    case previousChapter
    case nextChapter
    case next
    case setContinuousPlay(Bool)
    case setTrimSilence(Bool)
    /// Where the watch left an item it played on its own, for the phone to pick up.
    case setProgress(youtubeId: String, seconds: Double)
    /// The watch's own sync mode, reported for analytics — the phone has no other way to see
    /// it, since it lives in the watch's local `UserDefaults`, not anything synced across.
    case reportSyncMode(fullSync: Bool)

    public static let payloadKey = "watchRemoteCommand"
}

public struct WatchVolumeReading: Equatable, Sendable {
    public let value: Double
    public let date: Date

    public init(value: Double, date: Date) {
        self.value = value
        self.date = date
    }
}

/// Where the phone's volume landed: the crown turns it through the system, which tells neither side.
public enum WatchRemoteVolume {
    public static let key = "watchRemoteVolume"

    public static func message(_ value: Double) -> [String: Any] {
        [key: value]
    }

    public static func value(in message: [String: Any]) -> Double? {
        message[key] as? Double
    }
}
