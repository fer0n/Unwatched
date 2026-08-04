//
//  StatsActor.swift
//  Unwatched
//

import SwiftData
import Foundation
import UnwatchedShared

actor StatsActor: SharedContextActor {
    nonisolated let modelContainer: ModelContainer
    nonisolated let modelExecutor: any ModelExecutor

    init(writer: DataWriter) {
        modelContainer = writer.container
        modelExecutor = writer.executor
    }

    func getStats() throws -> [SendableWatchTimeEntry] {
        let descriptor = FetchDescriptor<WatchTimeEntry>(sortBy: [SortDescriptor(\.date)])
        let entries = try modelContext.fetch(descriptor)

        // Fetch all subscriptions to map channel IDs to names
        let subDescriptor = FetchDescriptor<Subscription>()
        let subscriptions = try modelContext.fetch(subDescriptor)

        var channelNames: [String: String] = [:]
        for sub in subscriptions {
            if let channelId = sub.youtubeChannelId {
                channelNames[channelId] = sub.title
            }
        }

        return entries.map { entry in
            SendableWatchTimeEntry(
                date: entry.date,
                channelId: entry.channelId,
                channelName: channelNames[entry.channelId] ?? entry.channelId,
                watchTime: entry.watchTime
            )
        }
    }

    func addWatchTime(videoId: String, day: Date, duration: TimeInterval) throws {
        var videoFetch = FetchDescriptor<Video>(predicate: #Predicate { $0.youtubeId == videoId })
        videoFetch.fetchLimit = 1
        guard let video = try modelContext.fetch(videoFetch).first,
              let channelId = video.subscription?.youtubeChannelId ?? video.youtubeChannelId else {
            return
        }

        let entryFetch = FetchDescriptor<WatchTimeEntry>(
            predicate: #Predicate { $0.channelId == channelId && $0.date == day }
        )
        // Duplicates exist until CleanupService merges them; the largest is the accumulated one
        if let entry = try modelContext.fetch(entryFetch).max(by: { $0.watchTime < $1.watchTime }) {
            entry.watchTime += duration
        } else {
            modelContext.insert(WatchTimeEntry(date: day, channelId: channelId, watchTime: duration))
        }
        try modelContext.save()
    }

    func deleteStats(from startDate: Date, to endDate: Date, channelId: String?) throws {
        let descriptor: FetchDescriptor<WatchTimeEntry>
        if let channelId {
            descriptor = FetchDescriptor<WatchTimeEntry>(
                predicate: #Predicate { $0.date >= startDate && $0.date < endDate && $0.channelId == channelId }
            )
        } else {
            descriptor = FetchDescriptor<WatchTimeEntry>(
                predicate: #Predicate { $0.date >= startDate && $0.date < endDate }
            )
        }

        let entries = try modelContext.fetch(descriptor)
        for entry in entries {
            modelContext.delete(entry)
        }
        try modelContext.save()
    }
}
