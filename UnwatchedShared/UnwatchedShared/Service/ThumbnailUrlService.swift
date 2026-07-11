//
//  ThumbnailUrlService.swift
//  UnwatchedShared
//
//  Builds a YouTube thumbnail URL at a given size, shared between the app (UrlService) and the
//  share extension so both can use the same thumbnail-loading views (e.g. VideoListItemThumbnail).
//

import Foundation

public enum ThumbnailUrlService {
    public enum Size {
        case small
        case medium
        case large
        case max
    }

    public static func getImageUrl(_ imageUrl: URL?, _ size: Size) -> URL? {
        // smallest: https://i.ytimg.com/vi/88bMVbx1dzM/default.jpg
        // small: https://i.ytimg.com/vi/88bMVbx1dzM/mqdefault.jpg
        // default/medium url: https://i.ytimg.com/vi/88bMVbx1dzM/hqdefault.jpg

        // larger: https://i.ytimg.com/vi/88bMVbx1dzM/sddefault.jpg
        // largest: https://i.ytimg.com/vi/88bMVbx1dzM/maxresdefault.jpg

        guard let imageUrl else { return nil }
        let urlString = imageUrl.absoluteString

        let replacement: String
        switch size {
        case .small:
            replacement = "mqdefault.jpg"
        case .medium:
            replacement = "hqdefault.jpg"
        case .large:
            replacement = "sddefault.jpg"
        case .max:
            replacement = "maxresdefault.jpg"
        }
        let qualities = ["maxresdefault.jpg", "sddefault.jpg", "hqdefault.jpg", "mqdefault.jpg", "default.jpg"]
        for quality in qualities where urlString.contains(quality) {
            let newString = urlString.replacing(quality, with: replacement)
            return URL(string: newString)
        }
        return imageUrl
    }
}
