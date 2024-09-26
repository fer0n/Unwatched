//
//  UnwatchedSchemaV1.swift
//  Unwatched
//

import SwiftData
import SwiftUI

enum CachedImageSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [CachedImage.self]
    }

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
}
