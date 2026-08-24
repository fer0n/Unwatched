//
//  TrimSilenceTier.swift
//  UnwatchedShared
//

import Foundation

/// How aggressively "trim silence" shortens the pauses in an episode.
public enum TrimSilenceTier: Int, Codable, CaseIterable, Sendable {
    case mild
    case medium
    case max

    public struct Settings: Sendable {
        /// How much of a pause at either end is left at its original length.
        public let guardBand: Double
        /// Shortest run of quiet this tier calls a pause.
        public let minimumPause: Double
        /// Length a short pause is cut to, before the guard-band floor is applied.
        public let targetPause: Double
        /// Share of a long pause's own length that's kept, on top of `targetPause`'s floor.
        public let keepFraction: Double
        /// Least a pause has to save to be worth trimming at all.
        public let minimumSaving: Double
    }

    public var settings: Settings {
        switch self {
        case .mild:
            return Settings(
                guardBand: Const.silenceGuardBand,
                minimumPause: 0.5,
                targetPause: 0.6,
                keepFraction: 0.55,
                minimumSaving: 0.3
            )
        case .medium:
            return Settings(
                guardBand: Const.silenceGuardBand,
                minimumPause: Const.silenceMinimumPause,
                targetPause: Const.silenceTargetPause,
                keepFraction: Const.silenceKeepFraction,
                minimumSaving: Const.silenceMinimumSaving
            )
        case .max:
            return Settings(
                guardBand: 0.1,
                minimumPause: 0.3,
                targetPause: 0.2,
                keepFraction: 0.15,
                minimumSaving: 0.08
            )
        }
    }

    /// The tier that keeps the widest set of pauses — a scan filters against this one, so any tier
    /// picked afterwards can be applied to the same cached scan.
    public static var mostPermissive: TrimSilenceTier { .max }

    /// The stored setting, or `.medium` when unset or invalid.
    public static var current: TrimSilenceTier {
        guard let raw = UserDefaults.standard.object(forKey: Const.trimSilenceTier) as? Int,
              let tier = TrimSilenceTier(rawValue: raw) else {
            return .medium
        }
        return tier
    }

    public var description: String {
        switch self {
        case .mild: return String(localized: "trimSilenceTierMild")
        case .medium: return String(localized: "trimSilenceTierMedium")
        case .max: return String(localized: "trimSilenceTierMax")
        }
    }
}
