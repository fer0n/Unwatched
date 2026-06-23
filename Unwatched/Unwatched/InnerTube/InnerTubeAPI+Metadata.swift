//
//  InnerTubeAPI+Metadata.swift
//  Unwatched
//
//  Unwatched-owned extension (not part of the upstream SmartTube sync). Fetches only the
//  metadata fields from the InnerTube player endpoint, independent of stream resolution.
//

import Foundation

extension InnerTubeAPI {

    /// Fetches a video's description from the InnerTube player endpoint
    /// (`videoDetails.shortDescription`). Unlike `fetchPlayerInfo`, this only reads
    /// `videoDetails`, so it succeeds even for videos whose playable streams can't be
    /// resolved (e.g. without a PO token). Used to backfill the description for videos
    /// added without one — e.g. from the search tab — avoiding the YouTube Data API.
    /// Returns nil when no description is present.
    func fetchVideoDescription(videoId: String) async throws -> String? {
        var body = makeBody(client: iosClientContext)
        body["videoId"] = videoId
        body["racyCheckOk"] = true
        body["contentCheckOk"] = true
        let data = try await postPlayer(body: body)
        let videoDetails = data["videoDetails"] as? [String: Any]
        return videoDetails?["shortDescription"] as? String
    }
}
