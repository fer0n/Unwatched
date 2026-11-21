//
//  PlaybackPositionBackup.swift
//  UnwatchedShared
//

import Foundation
import SwiftData

/// Playback position kept outside SwiftData (no CloudKit export), restored after a kill.
@MainActor
public enum PlaybackPositionBackup {
    private struct Entry: Codable {
        let youtubeId: String
        let time: Double
        let savedAt: Date
    }

    static let writeIntervalSeconds: TimeInterval = 5
    /// Older than this, another device may have played further.
    static let maxAge: TimeInterval = 15 * 60

    public static var defaultEnabled: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    public static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Const.playbackPositionBackup) as? Bool ?? defaultEnabled
    }

    private static var lastWrite: Date?

    private static let fileUrl: URL = {
        let dir = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "playbackPositionBackup.json")
    }()

    /// - Parameter force: skip the throttle, for positions saved outside the playing tick
    public static func record(_ time: Double, youtubeId: String?, force: Bool = false) {
        let now = Date()
        if !force, let lastWrite, now.timeIntervalSince(lastWrite) < writeIntervalSeconds { return }
        guard isEnabled, let youtubeId, time.isFinite, time >= 0 else { return }
        lastWrite = now
        do {
            let data = try JSONEncoder().encode(Entry(youtubeId: youtubeId, time: time, savedAt: now))
            try data.write(to: fileUrl, options: .atomic)
        } catch {
            Log.warning("PlaybackPositionBackup: write failed: \(error)")
        }
    }

    public static func applyToStore() {
        guard let data = try? Data(contentsOf: fileUrl) else { return }
        try? FileManager.default.removeItem(at: fileUrl)
        guard isEnabled else { return }
        guard let entry = try? JSONDecoder().decode(Entry.self, from: data) else {
            Log.warning("PlaybackPositionBackup: unreadable backup")
            return
        }
        guard (0..<maxAge).contains(Date().timeIntervalSince(entry.savedAt)) else { return }

        let context = DataProvider.mainContext
        let youtubeId = entry.youtubeId
        let fetch = FetchDescriptor<Video>(predicate: #Predicate { $0.youtubeId == youtubeId })
        let unfinishedCopies = ((try? context.fetch(fetch)) ?? []).filter {
            $0.watchedDate == nil && $0.clearedDate == nil && $0.elapsedSeconds != entry.time
        }
        for video in unfinishedCopies {
            Log.info("PlaybackPositionBackup: \(video.elapsedSeconds ?? 0) → \(entry.time)")
            video.elapsedSeconds = entry.time
        }
        if context.hasChanges {
            try? context.save()
        }
    }
}
