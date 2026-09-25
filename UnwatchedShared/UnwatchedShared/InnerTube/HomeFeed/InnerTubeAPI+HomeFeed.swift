//
//  InnerTubeAPI+HomeFeed.swift
//  UnwatchedShared
//

import Foundation

extension InnerTubeAPI {
    /// Parses a `browse` or `next` response; raw text so even the ~1.5 MB UTF-8 copy is off the caller's actor.
    public func parseVideoPage(json text: String) -> SearchPage {
        guard let json = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else {
            return SearchPage(videos: [], nextPageToken: nil)
        }
        return parseSearchPage(from: json)
    }
}
