//
//  VideoInfoService.swift
//  UnwatchedShared
//

import Foundation

public enum VideoInfoService {
    private static let api = InnerTubeAPI()

    /// InnerTube first to save Data API quota; the Data API reports nonexistent ids.
    public static func getVideoInfo(_ youtubeId: String) async throws -> SendableVideo? {
        do {
            if let info = try await api.fetchVideoInfo(videoId: youtubeId) {
                return info
            }
            Log.refresh.info("getVideoInfo: \(youtubeId) incomplete from InnerTube, using the Data API")
        } catch {
            try Task.checkCancellation()
            Log.refresh.warning("getVideoInfo: InnerTube failed for \(youtubeId), using the Data API: \(error)")
        }
        return try await YoutubeDataAPI.getYtVideoInfo(youtubeId)
    }
}
