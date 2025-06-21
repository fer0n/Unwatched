//
//  UnwatchedSchemaV1.swift
//  Unwatched
//

import SwiftData
import SwiftUI

enum CachedImageSchemaV1p1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 1, 0)

    static var models: [any PersistentModel.Type] {
        [CachedImage.self]
    }

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
}
