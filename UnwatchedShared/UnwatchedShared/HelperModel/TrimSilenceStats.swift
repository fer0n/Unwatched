//
//  TrimSilenceStats.swift
//  UnwatchedShared
//

import Foundation

/// The two running totals behind the "time saved" readout, both in the listener's own seconds:
/// the engine's clocks run at the playback rate, so what they count is worth that much less of a life.
public struct TrimSilenceStats: Sendable, Equatable {
    /// Seconds the listener got back because silence never played.
    public let saved: Double
    /// Seconds spent listening while trimming was on. Nothing reads it back yet; it is kept so the
    /// saving can be stated as a speed again without counting from scratch.
    public let played: Double

    public init(saved: Double, played: Double) {
        self.saved = saved
        self.played = played
    }

    public static var current: TrimSilenceStats {
        TrimSilenceStats(
            saved: UserDefaults.standard.double(forKey: Const.trimSilenceSecondsSaved),
            played: UserDefaults.standard.double(forKey: Const.trimSilenceSecondsPlayed)
        )
    }
}

public extension TrimSilenceStats {
    /// The engine's two clocks at one tick, both in episode seconds, on the timeline they were read from.
    struct Reading: Sendable, Equatable {
        public let rendered: Double
        public let episode: Double
        /// Bumped whenever the engine's timeline is rebuilt; two readings only subtract within one.
        public let epoch: Int
        public let rate: Double

        public init(rendered: Double, episode: Double, epoch: Int, rate: Double) {
            self.rendered = rendered
            self.episode = episode
            self.epoch = epoch
            self.rate = rate
        }
    }

    /// What one tick of playback adds to the totals, or nil when the two readings don't describe
    /// a tick: a seek restarts the rendered clock, and subtracting across one counts the jump as
    /// a saving.
    static func tick(from previous: Reading, to current: Reading) -> TrimSilenceStats? {
        guard previous.epoch == current.epoch, current.rate > 0,
              previous.rendered.isFinite, previous.episode.isFinite,
              current.rendered.isFinite, current.episode.isFinite else {
            return nil
        }
        func listenerSeconds(_ episodeSeconds: Double) -> Double { episodeSeconds / current.rate }

        // a tick renders the rate itself: anything else is a loop, a stall, or a gap between ticks
        let rendered = current.rendered - previous.rendered
        guard rendered > 0, rendered < current.rate + 1 else { return nil }
        return TrimSilenceStats(
            saved: listenerSeconds(Swift.max(0, (current.episode - previous.episode) - rendered)),
            played: listenerSeconds(rendered)
        )
    }

    static func + (lhs: TrimSilenceStats, rhs: TrimSilenceStats) -> TrimSilenceStats {
        TrimSilenceStats(saved: lhs.saved + rhs.saved, played: lhs.played + rhs.played)
    }
}
