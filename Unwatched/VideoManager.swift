//
//  VideoManager.swift
//  Unwatched
//

import SwiftData
import SwiftUI

@Observable class VideoManager {
    // This will hold the videos loaded from the RSS feeds
    var videos: [Video] = []

    // Define your RSS feeds here
    private let feedUrls = [
        "https://www.youtube.com/feeds/videos.xml?channel_id=UCsmk8NDVMct75j_Bfb9Ah7w",
        // Add more RSS feed URLs here
    ]

func loadVideos() async {
    for feedUrl in feedUrls {
        do {
            // Use VideoCrawler to load the videos from the RSS feed
            let loadedVideos = try await VideoCrawler.loadVideosFromRSS(feedUrl: feedUrl)
            print("loadedVideos", loadedVideos)
            videos.append(contentsOf: loadedVideos)
        } catch {
            print("Failed to load videos from \(feedUrl): \(error)")
        }
    }
}
}
