//
//  CachedImage.swift
//  Unwatched
//

import Foundation
import SwiftData

@Model final class CachedImage {
    var imageUrl: URL?
    @Attribute(.externalStorage) var imageData: Data?
    var video: Video?
    var createdOn: Date?

    init(_ imageUrl: URL, imageData: Data, video: Video? = nil) {
        self.imageUrl = imageUrl
        self.imageData = imageData
        self.video = video
        self.createdOn = .now
    }
}
