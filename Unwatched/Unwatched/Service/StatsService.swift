//
//  StatsService.swift
//  Unwatched
//

import Foundation
import SwiftData
import UnwatchedShared
import OSLog

@MainActor
final class StatsService {
    static let shared = StatsService()

    private var currentVideoId: String?
    private var lastVideoTime: Double?
    private var lastWallClockTime: Date?

    private let statsActor = StatsActor(modelContainer: DataProvider.shared.container)

    private init() {}

    func handleVideoTimeUpdate(videoId: String, time: Double) {
        let now = Date()
        defer {
            if currentVideoId != videoId { currentVideoId = videoId }
            lastVideoTime = time
            lastWallClockTime = now
        }

        guard videoId == currentVideoId,
              let last = lastVideoTime,
              let lastClock = lastWallClockTime else { return }

        // Video must have actually advanced (guards against buffering and backward seeks)
        guard time > last else { return }

        let wallClockDelta = now.timeIntervalSince(lastClock)
        // Cap to prevent runaway accumulation if the timer fires late
        let duration = min(wallClockDelta, Double(Const.updateDbTimeSeconds) + 5)
        guard duration > 0 else { return }

        Log.info("StatsService: +\(duration)s for \(videoId)")

        guard let day = getNormalizedDate(now) else { return }
        let actor = statsActor
        Task {
            do {
                try await actor.addWatchTime(videoId: videoId, day: day, duration: duration)
            } catch {
                Log.error("StatsService: Failed to save stat: \(error)")
            }
        }
    }

    func getNormalizedDate(_ date: Date) -> Date? {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar.date(from: components)
    }
}
