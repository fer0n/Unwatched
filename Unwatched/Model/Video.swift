//
//  Video.swift
//  Unwatched
//

import Foundation
import SwiftData

@Model
final class Video: CustomStringConvertible {
    var title: String
    var url: URL
    var youtubeId: String
    var thumbnailUrl: URL

    init(title: String, url: URL, youtubeId: String, thumbnailUrl: URL) {
        self.title = title
        self.url = url
        self.youtubeId = youtubeId
        self.thumbnailUrl = thumbnailUrl
    }

    // specify what is being printed when you print an instance of this class directly
    var description: String {
        return "Video: \(title) (\(url))"
    }
}
