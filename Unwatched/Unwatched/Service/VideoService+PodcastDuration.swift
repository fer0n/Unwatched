import SwiftData
import UnwatchedShared

extension VideoService {
    /// For feeds with an empty `itunes:duration`.
    @MainActor
    static func fillPodcastDurationsFromDownloads() async {
        for youtubeId in PodcastDownloadManager.shared.downloadedIds {
            await fillPodcastDurationFromDownload(youtubeId: youtubeId)
        }
    }

    @MainActor
    static func fillPodcastDurationFromDownload(youtubeId: String) async {
        guard videoWithoutDuration(youtubeId) != nil,
              let duration = await PodcastDownloadStore.downloadedDuration(for: youtubeId),
              let video = videoWithoutDuration(youtubeId) else {
            return
        }
        updateDurationAndChapters(video, duration: duration)
    }

    @MainActor
    private static func videoWithoutDuration(_ youtubeId: String) -> Video? {
        var fetch = FetchDescriptor<Video>(predicate: #Predicate { $0.youtubeId == youtubeId && $0.duration == nil })
        fetch.fetchLimit = 1
        return try? DataProvider.mainContext.fetch(fetch).first
    }
}
