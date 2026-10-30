//
//  RecentSpeeds.swift
//  UnwatchedShared
//

import Foundation

/// The quick speeds in the speed menus: 1× and the speeds the user played at most recently.
///
/// Stored as a comma-separated string, most recent first, because settings backups only
/// round-trip scalar values.
public enum RecentSpeeds {
    /// Fill the slots until enough speeds have been used.
    public static let defaults: [Double] = [1.3, 1.5, 2]
    /// Next to 1×, which always stays.
    public static let slots = 3
    /// Playback at a speed before it counts as used, so stepping through speeds doesn't record
    /// every speed on the way.
    public static let usageThreshold: TimeInterval = 60

    /// Sorted ascending, so a button doesn't move when the ranking changes.
    public static func menuSpeeds(_ stored: String) -> [Double] {
        var speeds: [Double] = []
        for speed in decode(stored) + defaults where !contains(speeds + [1], speed) {
            speeds.append(speed)
            if speeds.count == slots { break }
        }
        return ([1] + speeds).sorted()
    }

    public static func recording(_ speed: Double, in stored: String) -> String {
        guard !SpeedHelper.isSame(speed, 1) else {
            return stored
        }
        let others = decode(stored).filter { !SpeedHelper.isSame($0, speed) }
        return encode(Array(([speed] + others).prefix(slots)))
    }

    /// Playback time at the current speed, fed by the player's once-a-second tick.
    public struct Usage: Sendable {
        /// Ticks further apart than this mean playback stopped in between. Above the 1s tick
        /// so a throttled background web view still counts.
        static let maxTickGap: TimeInterval = 5

        var speed: Double?
        var played: TimeInterval = 0
        var lastTick: Date?

        public init() {}

        /// Whether this tick took the speed past the threshold, i.e. it should be recorded now.
        public mutating func tick(speed: Double, now: Date = .now) -> Bool {
            guard let current = self.speed, SpeedHelper.isSame(current, speed), let lastTick else {
                self = Usage(speed: speed, played: 0, lastTick: now)
                return false
            }
            let before = played
            played += min(max(now.timeIntervalSince(lastTick), 0), Self.maxTickGap)
            self.lastTick = now
            return before < RecentSpeeds.usageThreshold && played >= RecentSpeeds.usageThreshold
        }

        init(speed: Double?, played: TimeInterval, lastTick: Date?) {
            self.speed = speed
            self.played = played
            self.lastTick = lastTick
        }
    }

    static func decode(_ stored: String) -> [Double] {
        stored.split(separator: ",").compactMap { Double($0) }.filter { $0 > 0 }
    }

    static func encode(_ speeds: [Double]) -> String {
        speeds.map { String($0) }.joined(separator: ",")
    }

    private static func contains(_ speeds: [Double], _ speed: Double) -> Bool {
        speeds.contains { SpeedHelper.isSame($0, speed) }
    }
}
