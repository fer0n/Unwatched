//
//  TrimSilenceStats.swift
//  UnwatchedShared
//

import Foundation

/// The two running totals behind the "time saved" readout.
public struct TrimSilenceStats: Sendable, Equatable {
    /// Seconds of episode that never played.
    public let saved: Double
    /// Seconds of audio rendered while trimming was on.
    public let played: Double

    public init(saved: Double, played: Double) {
        self.saved = saved
        self.played = played
    }

    /// A saving with no listening behind it predates `played` and would divide into a wild multiplier.
    public init(storedSaved: Double, storedPlayed: Double) {
        self.init(saved: storedPlayed > 0 ? storedSaved : 0, played: storedPlayed)
    }

    public static var current: TrimSilenceStats {
        TrimSilenceStats(
            storedSaved: UserDefaults.standard.double(forKey: Const.trimSilenceSecondsSaved),
            storedPlayed: UserDefaults.standard.double(forKey: Const.trimSilenceSecondsPlayed)
        )
    }

    /// What trimming multiplies playback by; 1 until there is enough listening to divide by.
    public var multiplier: Double {
        guard played >= 1, saved > 0 else { return 1 }
        return (played + saved) / played
    }

    /// A lifetime average: a per-episode ratio swings about and resets on every seek.
    public func effectiveSpeed(at rate: Double) -> Double {
        rate * multiplier
    }
}
