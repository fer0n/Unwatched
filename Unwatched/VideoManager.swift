//
//  VideoManager.swift
//  Unwatched
//

import SwiftData
import SwiftUI
import Observation

class VideoManager {

    static func markVideoWatched(queueEntry: QueueEntry,
                                 queue: [QueueEntry],
                                 modelContext: ModelContext ) {
        queueEntry.video.watched = true
        let watchEntry = WatchEntry(video: queueEntry.video)
        modelContext.insert(watchEntry)
        QueueManager.deleteQueueEntry(queueEntry, modelContext: modelContext)
    }

    static func triageSubscriptionVideos(_ subVideo: (sub: Subscription, videos: [Video]),
                                         defaultPlacement: VideoPlacement,
                                         queue: [QueueEntry],
                                         limitVideos: Int?,
                                         modelContext: ModelContext) {
        let videosToAdd = limitVideos == nil ? subVideo.videos : Array(subVideo.videos.prefix(limitVideos!))

        var placement = subVideo.sub.placeVideosIn
        if subVideo.sub.placeVideosIn == .defaultPlacement {
            placement = defaultPlacement
        }
        if placement == .inbox {
            addVideosToInbox(videosToAdd, modelContext: modelContext)
        } else if placement == .queue {
            QueueManager.insertQueueEntries(videos: videosToAdd, modelContext: modelContext)
        }
    }

    static func addVideosToInbox(_ videos: [Video], modelContext: ModelContext) {
        for video in videos {
            video.status = .inbox
            let inboxEntry = InboxEntry(video: video)
            modelContext.insert(inboxEntry)
        }
    }

    static nonisolated func getSubVideos(
        subscriptions: [Subscription]
    ) async -> [(sub: Subscription, videos: [Video])] {
        var subVideos: [(sub: Subscription, videos: [Video])] = []
        await withTaskGroup(of: (Subscription, [Video]).self) { taskGroup in
            for sub in subscriptions {
                taskGroup.addTask {
                    do {
                        print(">start \(sub.link)")
                        // Perform the asynchronous video loading
                        let loadedVideos = try await VideoCrawler.loadVideosFromRSS(
                            url: sub.link,
                            mostRecentPublishedDate: sub.mostRecentVideoDate)
                        print("STOP \(sub.link)")

                        return (sub, loadedVideos)
                    } catch {
                        print("Failed to load videos from \(sub.link): \(error)")
                        return (sub, [])
                    }
                }
            }
            for await result in taskGroup {
                let (sub, videos) = result
                subVideos.append((sub: sub, videos: videos))
            }
        }
        return subVideos
    }

    // TODO: Background thread?
    static func loadVideos(subscriptions: [Subscription],
                           defaultVideoPlacement: VideoPlacement,
                           queue: [QueueEntry],
                           modelContext: ModelContext) async -> [(sub: Subscription, videos: [Video])] {
        print(">START loadVideos")
        let subVideos =  await getSubVideos(subscriptions: subscriptions)
        // Perform the rest of the processing outside the detached task
        handleSubscriptionVideos(subVideos,
                                 defaultVideoPlacement: defaultVideoPlacement,
                                 queue: queue,
                                 modelContext: modelContext)

        print(">STOP loadVideos")
        return subVideos
    }

    static func handleSubscriptionVideos(_ subscriptionVideos: [(sub: Subscription, videos: [Video])],
                                         defaultVideoPlacement: VideoPlacement,
                                         queue: [QueueEntry],
                                         modelContext: ModelContext) {
        for subVideo in subscriptionVideos {
            for video in subVideo.videos {
                modelContext.insert(video)
            }
            subVideo.sub.videos.append(contentsOf: subVideo.videos)
            let limitVideos = subVideo.sub.mostRecentVideoDate == nil ? 5 : nil
            triageSubscriptionVideos(subVideo,
                                     defaultPlacement: defaultVideoPlacement,
                                     queue: queue,
                                     limitVideos: limitVideos,
                                     modelContext: modelContext)
            updateRecentVideoDate(subscription: subVideo.sub, videos: subVideo.videos)
        }
    }

    static func updateRecentVideoDate(subscription: Subscription, videos: [Video]) {
        let dates = videos.compactMap { $0.publishedDate }
        if let mostRecentDate = dates.max() {
            subscription.mostRecentVideoDate = mostRecentDate
        }
    }
}
