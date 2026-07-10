//
//  AnalyticsEvent.swift
//  Unwatched
//

import Foundation

struct AnalyticsEvent: Codable {
    let name: String
    let params: [String: String]
    let clientTimestamp: Double
    let userId: String?

    /// `includeUserId` controls whether the per-install `userId` rides along. Almost all
    /// events set it — it powers active-user counts (DAU/WAU/MAU) and per-feature reach
    /// (distinct users per event). Events that feed no per-user query — e.g. `Error` — pass
    /// `false` so they never contribute to a per-user profile or inflate active-user counts.
    /// A nil `userId` is omitted from the payload; the Worker maps it to "unknown", which the
    /// dashboard's user-count queries already exclude.
    init(name: String, params: [String: String] = [:], includeUserId: Bool = true) {
        self.name = name
        self.params = params
        // Truncated to the minute (kept as ms-since-epoch) so a per-user event stream can't
        // be reconstructed into a fine-grained timeline. Costs no metric accuracy: dashboard
        // time-series bucket by the Worker's ingestion timestamp, not clientTimestamp — which
        // is only used for snapshot dedup ordering and the recent-events feed.
        let minuteFloor = (Date().timeIntervalSince1970 / 60).rounded(.down) * 60
        self.clientTimestamp = minuteFloor * 1000
        self.userId = includeUserId ? AnalyticsEvent.anonymousUserId : nil
    }

    private static let userIdKey = "unwatched.analyticsUserId"

    /// Random, non-identifying id stored only in local UserDefaults (not part of
    /// Const.settingsDefaults, so it's excluded from iCloud sync/backup restore).
    /// Resets on reinstall. Used to count unique/active users and to dedupe
    /// per-user settings snapshots for the dashboard, never anything identifying.
    static var anonymousUserId: String {
        if let id = UserDefaults.standard.string(forKey: userIdKey) {
            return id
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: userIdKey)
        return id
    }
}
