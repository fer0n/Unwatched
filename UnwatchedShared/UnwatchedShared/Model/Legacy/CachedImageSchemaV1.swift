//
//  UnwatchedSchemaV1.swift
//  Unwatched
//

import SwiftData
import SwiftUI

public enum CachedImageSchemaV1: VersionedSchema {
    public static var versionIdentifier = Schema.Version(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [CachedImage.self]
    }

    @Model public final class CachedImage {
        public var imageUrl: URL?
        @Attribute(.externalStorage) var imageData: Data?
        public var createdOn: Date?

        public init(_ imageUrl: URL, imageData: Data) {
            self.imageUrl = imageUrl
            self.imageData = imageData
            self.createdOn = .now
        }
    }
}
