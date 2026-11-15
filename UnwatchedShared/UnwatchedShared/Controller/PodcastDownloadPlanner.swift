//
//  PodcastDownloadPlanner.swift
//  UnwatchedShared
//

import Foundation
import SwiftData

struct PendingPodcastDownload: Sendable {
    let youtubeId: String
    let url: URL
    let allowsCellular: Bool
}

struct PodcastDownloadPlan: Sendable {
    /// Every episode whose file may stay on disk; anything else is swept.
    var keep = Set<String>()
    var download = [PendingPodcastDownload]()
    /// For `PodcastDownloadStore.leftWindowDates`, stored by `sync()` alone.
    var leftWindowDates = [String: Date]()
}

actor PodcastDownloadActor: SharedContextActor {
    func plan(limitHours: Int, cellularHours: Int, keepDays: Int, playing: String?) -> PodcastDownloadPlan {
        PodcastDownloadPlanner.plan(
            in: modelContext,
            limitHours: limitHours,
            cellularHours: cellularHours,
            keepDays: keepDays,
            playing: playing
        )
    }
}

/// Split out from the actor: the watch plans against whichever store it is reading, never against
/// `DataProvider.shared`, which is what the actor is bound to.
enum PodcastDownloadPlanner {
    /// Takes the playing episode, then walks the queue in play order until `limitHours` of unplayed time is covered,
    /// and decides how long the files outside it have left. The episode that crosses the limit is still taken whole.
    /// The first `cellularHours` of that walk may download on cellular data, measured the same way.
    static func plan(
        in context: ModelContext,
        limitHours: Int,
        cellularHours: Int,
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
                add(video, allowsCellular: true, to: &plan)
            }
        }

        if enabled {
            var budget = seconds(limitHours)
            var cellularBudget = seconds(cellularHours)
            var fetch = FetchDescriptor<QueueEntry>(sortBy: [SortDescriptor(\.order)])
            fetch.relationshipKeyPathsForPrefetching = [\.video]
            for entry in (try? context.fetch(fetch)) ?? [] {
                guard budget > 0 else { break }
                guard let video = entry.video,
                      video.mediaUrl != nil,
                      video.watchedDate == nil else {
                    continue
                }
                let duration = video.remainingTime ?? video.duration ?? 0
                add(video, allowsCellular: cellularBudget > 0, to: &plan)
                budget -= duration
                cellularBudget -= duration
            }
        }

        keepRecentlyLeft(in: context, keepDays: enabled ? keepDays : 0, plan: &plan)
        return plan
    }

    /// Counted from `watchedDate`, else from the first plan that found the episode outside the window.
    private static func keepRecentlyLeft(in context: ModelContext, keepDays: Int, plan: inout PodcastDownloadPlan) {
        let onDisk = PodcastDownloadStore.downloadedIds().subtracting(plan.keep)
        plan.leftWindowDates = PodcastDownloadStore.leftWindowDates.filter { onDisk.contains($0.key) }
        guard keepDays > 0, !onDisk.isEmpty else { return }

        let expiry = Calendar.current.date(byAdding: .day, value: -keepDays, to: .now) ?? .now
        let ids = Array(onDisk)
        let fetch = FetchDescriptor<Video>(predicate: #Predicate { ids.contains($0.youtubeId) })
        for video in (try? context.fetch(fetch)) ?? [] {
            let leftWindowDate: Date
            if let watchedDate = video.watchedDate {
                leftWindowDate = watchedDate
            } else {
                leftWindowDate = plan.leftWindowDates[video.youtubeId] ?? .now
                plan.leftWindowDates[video.youtubeId] = leftWindowDate
            }
            if leftWindowDate > expiry {
                plan.keep.insert(video.youtubeId)
            }
        }
    }

    private static func seconds(_ hours: Int) -> Double {
        hours < 0 ? .infinity : Double(hours) * 3600
    }

    private static func add(_ video: Video, allowsCellular: Bool, to plan: inout PodcastDownloadPlan) {
        guard let mediaUrl = video.mediaUrl, !plan.keep.contains(video.youtubeId) else { return }
        plan.keep.insert(video.youtubeId)
        guard PodcastDownloadStore.playbackUrl(for: video) == nil else { return }
        plan.download.append(PendingPodcastDownload(
            youtubeId: video.youtubeId,
            url: mediaUrl,
            allowsCellular: allowsCellular
        ))
    }
}
