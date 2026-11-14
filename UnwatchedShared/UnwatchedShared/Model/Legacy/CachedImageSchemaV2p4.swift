//
//  CachedImageSchemaV2p4.swift
//  UnwatchedShared
//

import SwiftData

public enum CachedImageSchemaV2p4: VersionedSchema {
    public static let versionIdentifier = Schema.Version(2, 4, 0)

    public static var models: [any PersistentModel.Type] {
        [CachedImage.self, Transcript.self, CachedChapters.self, CachedEpisode.self, CachedVideoFeed.self]
    }

    @Model public final class CachedImage {
        @Attribute(.unique) public var imageUrl: URL?
        @Attribute(.externalStorage) public var imageData: Data?
        public var createdOn: Date?
        public var lastAccessedOn: Date?
        public var colorHex: String?

        public init(_ imageUrl: URL, imageData: Data) {
            self.imageUrl = imageUrl
            self.imageData = imageData
            self.createdOn = .now
            self.lastAccessedOn = .now
        }
    }
}
