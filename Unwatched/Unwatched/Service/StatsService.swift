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

    /// Watch time accrued since the last flush. Writing on every sample would bump a
    /// CloudKit-mirrored counter row every 30s for as long as playback lasts; batching keeps that
    /// to a handful of writes per session, and gives concurrent devices fewer versions to merge.
    private var pending = [PendingWatchTime: TimeInterval]()
    private var flushTask: Task<Void, Never>?

    private let statsActor = StatsActor()

    private init() {}

    /// - Parameter persist: flush the accrued time right away (pause, video ended, backgrounding).
    func handleVideoTimeUpdate(videoId: String, time: Double, persist: Bool = false) {
        let now = Date()
        defer {
            if currentVideoId != videoId { currentVideoId = videoId }
            lastVideoTime = time
            lastWallClockTime = now
            if persist { flush() }
        }

        guard videoId == currentVideoId,
              let last = lastVideoTime,
              let lastClock = lastWallClockTime else { return }

        // Video must have actually advanced (guards against buffering and backward seeks)
        guard time > last else { return }

        let wallClockDelta = now.timeIntervalSince(lastClock)
        // Never credit more than the video itself advanced: a player left running on a stalled or
        // barely-progressing item can't accrue real time. Playback speed converts video seconds
        // back to wall-clock seconds, so 2x playback still counts as the time actually spent.
        let speed = max(PlayerManager.shared.playbackSpeed, 0.1)
        let watchedDelta = (time - last) / speed
        // Cap to prevent runaway accumulation if the timer fires late
        let duration = min(wallClockDelta, watchedDelta, Double(Const.updateDbTimeSeconds) + 5)
        guard duration > 0 else { return }

        guard let day = getNormalizedDate(now) else { return }
        pending[PendingWatchTime(videoId: videoId, day: day), default: 0] += duration
        scheduleFlush()
    }

    func flush() {
        flushTask?.cancel()
        flushTask = nil
        guard !pending.isEmpty else { return }

        let batch = pending
        pending = [:]
        Log.info("StatsService: flushing \(batch.values.reduce(0, +))s across \(batch.count) entries")

        let actor = statsActor
        Task {
            do {
                try await actor.addWatchTime(batch)
            } catch {
                Log.error("StatsService: Failed to save stats: \(error)")
            }
        }
    }

    /// Safety net for a session that never pauses — background audio can run for hours.
    private func scheduleFlush() {
        guard flushTask == nil else { return }
        flushTask = Task {
            try? await Task.sleep(for: .seconds(Const.statsFlushIntervalSeconds))
            guard !Task.isCancelled else { return }
            flushTask = nil
            flush()
        }
    }

    func getNormalizedDate(_ date: Date) -> Date? {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar.date(from: components)
    }
}
