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
    var publishedDate: Date?

    init(title: String, url: URL, youtubeId: String, thumbnailUrl: URL, publishedDate: Date?) {
        self.title = title
        self.url = url
        self.youtubeId = youtubeId
        self.thumbnailUrl = thumbnailUrl
        self.publishedDate = publishedDate
    }

    // specify what is being printed when you print an instance of this class directly
    var description: String {
        return "Video: \(title) (\(url))"
    }

    // Preview data
    static let dummy = Video(
        title: "Virtual Reality OasisResident Evil 4 Remake Is 10x BETTER In VR!",
        url: URL(string: "https://www.youtube.com/watch?v=_7vP9vsnYPc")!,
        youtubeId: "_7vP9vsnYPc",
        thumbnailUrl: URL(string: "https://i4.ytimg.com/vi/_7vP9vsnYPc/hqdefault.jpg")!,
        publishedDate: Date())
}
