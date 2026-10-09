//
//  PlaybackPositionSync.swift
//  Unwatched
//

import Foundation
import UnwatchedShared

/// Other devices only take a position over if it was played later than their own last play, pause or seek
@MainActor
final class PlaybackPositionSync {
    static let shared = PlaybackPositionSync()

    private static let publishInterval: TimeInterval = 60
    private static let maxInteractions = 30

    private struct Record: Codable {
        let youtubeId: String
        let seconds: Double
        let playedAt: Date
    }

    private let cloud = NSUbiquitousKeyValueStore.default
    private var lastPublished: Date?
    private var interactions: [String: Date]

    private init() {
        interactions = UserDefaults.standard.dictionary(forKey: Const.localPlaybackInteractions)
            as? [String: Date] ?? [:]
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: nil,
            queue: .main
        ) { notification in
            let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
            guard keys.contains(Const.playbackPositionRecord) else { return }
            MainActor.assumeIsolated {
                PlayerManager.shared.applyRemotePosition()
            }
        }
    }

    func noteInteraction(_ youtubeId: String, at date: Date = .now) {
        interactions[youtubeId] = date
        if interactions.count > Self.maxInteractions {
            let newest = interactions.sorted { $0.value > $1.value }.prefix(Self.maxInteractions)
            interactions = Dictionary(uniqueKeysWithValues: Array(newest))
        }
        UserDefaults.standard.set(interactions, forKey: Const.localPlaybackInteractions)
    }

    func publish(_ youtubeId: String, seconds: Double, throttled: Bool) {
        let now = Date.now
        if throttled, let lastPublished, now.timeIntervalSince(lastPublished) < Self.publishInterval {
            return
        }
        let record = Record(youtubeId: youtubeId, seconds: seconds, playedAt: now)
        guard let data = try? JSONEncoder().encode(record) else { return }
        noteInteraction(youtubeId, at: now)
        cloud.set(data, forKey: Const.playbackPositionRecord)
        lastPublished = now
    }

    func takeRemotePosition(for youtubeId: String) -> Double? {
        guard let data = cloud.data(forKey: Const.playbackPositionRecord),
              let record = try? JSONDecoder().decode(Record.self, from: data),
              record.youtubeId == youtubeId,
              record.playedAt > interactions[youtubeId] ?? .distantPast else {
            return nil
        }
        noteInteraction(youtubeId, at: record.playedAt)
        return record.seconds
    }
}
