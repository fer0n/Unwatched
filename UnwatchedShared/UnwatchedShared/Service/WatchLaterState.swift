//
//  WatchLaterState.swift
//  UnwatchedShared
//

import Foundation

/// Every Watch Later id this device has fetched, so a refresh only triages what's newly saved.
public enum WatchLaterState {
    public static func seenIds() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: Const.watchLaterSeenIds) ?? [])
    }

    public static func record(_ ids: [String]) {
        let seen = seenIds()
        let added = ids.filter { !seen.contains($0) }
        guard !added.isEmpty else { return }
        UserDefaults.standard.set(Array(seen) + added, forKey: Const.watchLaterSeenIds)
    }

    public static func reset() {
        UserDefaults.standard.removeObject(forKey: Const.watchLaterSeenIds)
    }
}
