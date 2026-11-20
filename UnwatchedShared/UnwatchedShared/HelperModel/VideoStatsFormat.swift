//
//  VideoStatsFormat.swift
//  UnwatchedShared
//

import Foundation

public enum VideoStatsFormat {
    public static func views(_ count: Int) -> String {
        if count < 1_000 {
            return String(localized: "\(count) views")
        }
        let compact = count.formatted(.number.notation(.compactName))
        return String(localized: "\(compact) views")
    }
}
