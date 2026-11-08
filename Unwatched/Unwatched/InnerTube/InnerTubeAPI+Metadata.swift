//
//  InnerTubeAPI+Metadata.swift
//  Unwatched
//
//  Unwatched-owned extension (not part of the upstream SmartTube sync). Fetches only the
//  metadata fields from the InnerTube player endpoint, independent of stream resolution.
//

import Foundation
import UnwatchedShared

extension InnerTubeAPI {

    struct VideoMetadata: Sendable {
        var description: String?
        var channelId: String?
        var channelTitle: String?
        /// True for live streams, upcoming or past; false for regular videos, premieres included.
        var isLiveContent: Bool?
        /// Not returned by `fetchVideoMetadata`
        var publishedDate: Date?
    }

    /// Fetches a video's description, channel and whether it's a stream from the InnerTube
    /// player endpoint. Unlike `fetchPlayerInfo`, this only reads `videoDetails`, so it succeeds
    /// even for videos whose playable streams can't be resolved (e.g. without a PO token).
    func fetchVideoMetadata(videoId: String) async throws -> VideoMetadata {
        var body = makeBody(client: iosClientContext)
        body["videoId"] = videoId
        body["racyCheckOk"] = true
        body["contentCheckOk"] = true
        let data = try await postPlayer(body: body)
        let videoDetails = data["videoDetails"] as? [String: Any]
        return VideoMetadata(
            description: videoDetails?["shortDescription"] as? String,
            channelId: videoDetails?["channelId"] as? String,
            channelTitle: videoDetails?["author"] as? String,
            isLiveContent: videoDetails?["isLiveContent"] as? Bool
        )
    }
}

extension InnerTubeAPI.VideoMetadata {
    init(_ video: SendableVideo?) {
        self.init(
            description: video?.videoDescription,
            channelId: video?.youtubeChannelId,
            channelTitle: video?.feedTitle,
            publishedDate: video?.publishedDate
        )
    }
}

extension Video {
    func apply(_ info: InnerTubeAPI.VideoMetadata) {
        if let description = info.description, videoDescription != description {
            videoDescription = description
        }
        if let date = info.publishedDate, publishedDate == nil {
            publishedDate = date
            if let inboxEntry, inboxEntry.date == nil {
                inboxEntry.date = date
            }
        }
    }
}
