//
//  CachedImage.swift
//  Unwatched
//

import Foundation
import SwiftData

@Model public final class CachedImage {
    @Attribute(.unique) public var imageUrl: URL?
    @Attribute(.externalStorage) public var imageData: Data?
    public var createdOn: Date?

    public init(_ imageUrl: URL, imageData: Data) {
        self.imageUrl = imageUrl
        self.imageData = imageData
        self.createdOn = .now
    }
}
