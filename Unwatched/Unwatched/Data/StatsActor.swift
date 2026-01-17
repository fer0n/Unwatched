//
//  StatsActor.swift
//  Unwatched
//

import SwiftData
import Foundation
import UnwatchedShared

@ModelActor
actor StatsActor {
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
