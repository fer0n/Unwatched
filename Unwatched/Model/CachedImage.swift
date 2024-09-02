//
//  CachedImage.swift
//  Unwatched
//

import Foundation
import SwiftData

@Model final class CachedImage {
    var imageUrl: URL?
    @Attribute(.externalStorage) var imageData: Data?
    var createdOn: Date?

    init(_ imageUrl: URL, imageData: Data) {
        self.imageUrl = imageUrl
        self.imageData = imageData
        self.createdOn = .now
    }
}
