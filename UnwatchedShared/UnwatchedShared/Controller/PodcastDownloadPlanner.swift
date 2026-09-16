//
//  PodcastDownloadPlanner.swift
//  UnwatchedShared
//

import Foundation
import SwiftData

struct PendingPodcastDownload: Sendable {
    let youtubeId: String
    let url: URL
}

struct PodcastDownloadPlan: Sendable {
    /// Every episode whose file may stay on disk; anything else is swept.
    var keep = Set<String>()
    var download = [PendingPodcastDownload]()
}

actor PodcastDownloadActor: SharedContextActor {
    func plan(limitHours: Int, keepDays: Int, playing: String?) -> PodcastDownloadPlan {
        PodcastDownloadPlanner.plan(in: modelContext, limitHours: limitHours, keepDays: keepDays, playing: playing)
    }
}

/// Split out from the actor: the watch plans against whichever store it is reading, never against
/// `DataProvider.shared`, which is what the actor is bound to.
enum PodcastDownloadPlanner {
    /// Takes the playing episode, then walks the queue in play order until `limitHours` of unplayed time is covered,
    /// and decides what a watched episode's file has left. The episode that crosses the limit is still taken whole.
    static func plan(
        in context: ModelContext,
        limitHours: Int,
        keepDays: Int,
        playing: String?
    ) -> PodcastDownloadPlan {
        var plan = PodcastDownloadPlan()
        let enabled = limitHours != 0

        // first in line, and regardless of the ahead-of-time limit: what's playing is what has the most to lose from
        // a connection dropping mid-episode
        if let playing {
            let fetch = FetchDescriptor<Video>(predicate: #Predicate { $0.youtubeId == playing })
            if let video = (try? context.fetch(fetch))?.first {
                add(video, to: &plan)
            }
        }

        if enabled {
            var budget = limitHours < 0 ? Double.infinity : Double(limitHours) * 3600
            let fetch = FetchDescriptor<QueueEntry>(sortBy: [SortDescriptor(\.order)])
            for entry in (try? context.fetch(fetch)) ?? [] {
                guard budget > 0 else { break }
                guard let video = entry.video,
                      video.mediaUrl != nil,
                      video.watchedDate == nil else {
                    continue
                }
                budget -= video.remainingTime ?? video.duration ?? 0
                add(video, to: &plan)
            }
        }

        guard enabled, keepDays > 0 else { return plan }
        let expiry = Calendar.current.date(byAdding: .day, value: -keepDays, to: .now) ?? .now
        let onDisk = Array(PodcastDownloadStore.downloadedIds().subtracting(plan.keep))
        guard !onDisk.isEmpty else { return plan }
        let fetch = FetchDescriptor<Video>(predicate: #Predicate { onDisk.contains($0.youtubeId) })
        for video in (try? context.fetch(fetch)) ?? [] {
            if let watchedDate = video.watchedDate, watchedDate > expiry {
                plan.keep.insert(video.youtubeId)
            }
        }
        return plan
    }

    private static func add(_ video: Video, to plan: inout PodcastDownloadPlan) {
        guard let mediaUrl = video.mediaUrl, !plan.keep.contains(video.youtubeId) else { return }
        plan.keep.insert(video.youtubeId)
        guard PodcastDownloadStore.playbackUrl(for: video) == nil else { return }
        plan.download.append(PendingPodcastDownload(youtubeId: video.youtubeId, url: mediaUrl))
    }
}
