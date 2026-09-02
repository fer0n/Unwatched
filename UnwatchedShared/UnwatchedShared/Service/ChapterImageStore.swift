//
//  ChapterImageStore.swift
//  UnwatchedShared
//

import Foundation

/// Where chapter artwork that arrives as bytes rather than a URL is put so the rest of the app can treat it like any
/// other image.
public enum ChapterImageStore {
    static let scheme = "unwatched-chapter"

    /// The URL the data was stored under, or nil for data that isn't an image.
    public static func store(_ data: Data, videoId: String, startTime: Double) async -> URL? {
        guard !data.isEmpty,
              let url = URL(string: "\(scheme)://\(videoId)/\(Int(startTime * 1000))") else {
            return nil
        }
        // replaced, not added: an entry an older build wrote for this chapter shouldn't win
        await ImageService.replaceImage(url: url, data: data)
        return url
    }
}
