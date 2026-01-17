//
//  StatsService.swift
//  Unwatched
//

import Foundation
import SwiftData
import UnwatchedShared
import OSLog
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
final class StatsService {
    static let shared = StatsService()

    private var currentVideoId: String?
    private var startTime: Date?
    private var pauseTask: Task<Void, Never>?

    private init() {
        #if os(iOS) || os(tvOS) || os(visionOS)
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.handleWillTerminate()
        }
        #elseif os(macOS)
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.handleWillTerminate()
        }
        #endif
    }

    private func handleWillTerminate() {
        Log.info("StatsService: handleWillTerminate")
        commitStats()
    }

    func handlePlay(_ videoId: String?) {
        guard let videoId else { return }

        if let currentVideoId, currentVideoId == videoId, let pauseTask {
            Log.info("StatsService: resume \(videoId), cancelling pause")
            pauseTask.cancel()
            self.pauseTask = nil
            return
        }

        // If we are switching videos, or starting fresh
        if let currentVideoId, currentVideoId != videoId {
            commitStats()
        }

        Log.info("StatsService: play \(videoId)")
        self.currentVideoId = videoId
        self.startTime = Date()
        self.pauseTask?.cancel()
        self.pauseTask = nil
    }

    func handlePause(_ videoId: String?) {
        guard let videoId, let currentVideoId, currentVideoId == videoId else { return }

        pauseTask?.cancel()
        pauseTask = Task {
            try? await Task.sleep(for: .seconds(1))
            if Task.isCancelled { return }

            commitStats()
        }
    }

    private func commitStats() {
        pauseTask?.cancel()
        pauseTask = nil

        guard let currentVideoId, let startTime else { return }

        let duration = Date().timeIntervalSince(startTime)
        guard duration > 0 else { return }

        Log.info("StatsService: commitStats \(currentVideoId), duration: \(duration)")

        let context = DataProvider.mainContext
        // Fetch video to get channel ID
        let predicate = #Predicate<Video> { $0.youtubeId == currentVideoId }
        let descriptor = FetchDescriptor(predicate: predicate)

        do {
            if let video = try context.fetch(descriptor).first {
                if let channelId = video.subscription?.youtubeChannelId ?? video.youtubeChannelId {
                    saveStat(channelId: channelId, duration: duration, context: context)
                }
            }
        } catch {
            Log.error("StatsService: Failed to fetch video: \(error)")
        }

        self.currentVideoId = nil
        self.startTime = nil
    }

    private func saveStat(channelId: String, duration: TimeInterval, context: ModelContext) {
        guard let today = getNormalizedDate(.now) else { return }

        let predicate = #Predicate<WatchTimeEntry> { $0.channelId == channelId && $0.date == today }
        let descriptor = FetchDescriptor(predicate: predicate)

        do {
            let stats = try context.fetch(descriptor)
            if let stat = stats.max(by: { $0.watchTime < $1.watchTime }) {
                stat.watchTime += duration
            } else {
                let stat = WatchTimeEntry(date: today, channelId: channelId, watchTime: duration)
                context.insert(stat)
            }
            try context.save()
        } catch {
            Log.error("StatsService: Failed to save stat: \(error)")
        }
    }

    func getNormalizedDate(_ date: Date) -> Date? {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar.date(from: components)
    }
}
