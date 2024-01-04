//
//  VideoManager.swift
//  Unwatched
//

import SwiftData
import SwiftUI
import Observation

@Observable class VideoManager {
    // This will hold the videos loaded from the RSS feeds
    var videos: [Video] = []

    init(videos: [Video]) {
        self.videos = videos
    }

    init() {}

    // Define your RSS feeds here
    private let feedUrls = [
        "https://www.youtube.com/feeds/videos.xml?channel_id=UCsmk8NDVMct75j_Bfb9Ah7w"
        // Add more RSS feed URLs here
    ]

    func loadVideos() async {
        for feedUrl in feedUrls {
            do {
                // Use VideoCrawler to load the videos from the RSS feed
                let loadedVideos = try await VideoCrawler.loadVideosFromRSS(feedUrl: feedUrl)
                videos.append(contentsOf: loadedVideos)
            } catch {
                print("Failed to load videos from \(feedUrl): \(error)")
            }
        }
    }

    // Preview data
    static let dummy = VideoManager(videos: [
        Video.dummy, Video.dummy, Video.dummy, Video.dummy, Video.dummy, Video.dummy
    ])
}
