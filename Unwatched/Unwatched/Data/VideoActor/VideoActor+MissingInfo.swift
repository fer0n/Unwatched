//
//  VideoActor+MissingInfo.swift
//  Unwatched
//

import SwiftData
import UnwatchedShared

extension VideoActor {
    /// Fetches the description, channel and upload date a video was created without, preferring
    /// InnerTube over the YouTube Data API to save quota. Returns nil when nothing is missing,
    /// and only the fields that were.
    func fetchMissingInfo(youtubeId: String) async -> InnerTubeAPI.VideoMetadata? {
        guard let existing = videoAlreadyExists(youtubeId) else { return nil }
        let needsDescription = existing.videoDescription?.isEmpty ?? true
        let needsChannel = existing.subscription == nil
        let needsDate = existing.publishedDate == nil && !existing.isPodcast
        guard needsDescription || needsChannel || needsDate else { return nil }
        let videoId = existing.persistentModelID

        var info = needsDate
            ? InnerTubeAPI.VideoMetadata(try? await VideoInfoService.getVideoInfo(youtubeId))
            : await fetchMetadata(youtubeId, needsDescription: needsDescription, needsChannel: needsChannel)

        if !needsDescription || info.description?.isEmpty ?? true {
            info.description = nil
        }
        if !needsDate {
            info.publishedDate = nil
        }
        if info.description != nil || info.publishedDate != nil,
           let video: Video = modelContext.resolvedModel(withID: videoId) {
            video.apply(info)
            try? modelContext.save()
        }
        if !needsChannel {
            info.channelId = nil
        }
        return info
    }

    private func fetchMetadata(
        _ youtubeId: String,
        needsDescription: Bool,
        needsChannel: Bool
    ) async -> InnerTubeAPI.VideoMetadata {
        var info = (try? await InnerTubeAPI().fetchVideoMetadata(videoId: youtubeId))
            ?? InnerTubeAPI.VideoMetadata()
        let gotDescription = !(info.description?.isEmpty ?? true)
        guard (needsDescription && !gotDescription) || (needsChannel && info.channelId == nil) else {
            return info
        }
        let fallback = try? await YoutubeDataAPI.getYtVideoInfo(youtubeId)
        Log.refresh.info("fetchMissingInfo: \(youtubeId) — InnerTube incomplete, Data API "
                            + (fallback == nil ? "failed too" : "succeeded"))
        info.description = gotDescription ? info.description : fallback?.videoDescription
        info.channelId = info.channelId ?? fallback?.youtubeChannelId
        info.channelTitle = info.channelTitle ?? fallback?.feedTitle
        return info
    }
}
