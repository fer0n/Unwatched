//
//  VideoManager.swift
//  Unwatched
//

import SwiftData
import SwiftUI
import Observation

@Observable class VideoManager {

    func queueVideo(_ video: Video, insertQueueEntry: @escaping (_ queueEntry: QueueEntry) -> Void) {
        let queueEntry = QueueEntry(video: video, order: 0)
        insertQueueEntry(queueEntry)
    }

    func loadVideos(subscriptions: [Subscription]) async -> [(sub: Subscription, videos: [Video])] {
        var subVideos: [(sub: Subscription, videos: [Video])] = []

        for sub in subscriptions {
            var videos: [Video] = []
            do {
                // Use VideoCrawler to load the videos from the RSS feed
                let loadedVideos = try await VideoCrawler.loadVideosFromRSS(
                    url: sub.link,
                    mostRecentPublishedDate: sub.mostRecentVideoDate)
                videos.append(contentsOf: loadedVideos)
            } catch {
                print("Failed to load videos from \(sub.link): \(error)")
            }
            // TODO: try doing this in parallel instead of one by one?
            subVideos.append((sub: sub, videos: videos))
        }
        return subVideos
    }

    func insertSubscriptionVideos(_ subscriptionVideos: [(sub: Subscription, videos: [Video])],
                                  insertVideo: @escaping (_ video: Video) -> Void) {
        for subVideo in subscriptionVideos {
            print("subVideo.videos", subVideo.videos)
            for video in subVideo.videos {
                insertVideo(video)
            }
            if let mostRecentDate = subVideo.videos.first?.publishedDate {
                print("mostRecentDate", mostRecentDate)
                // TODO: is this enough to update the model?
                subVideo.sub.mostRecentVideoDate = mostRecentDate
            }
        }
    }
}
