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

    /// `CachedEpisode` before `episodeNumber`, shared by 2.3.0 and 2.4.0.
    @Model public final class CachedEpisode {
        @Attribute(.unique) public var episodeId: String
        public var feedUrl: URL
        public var title: String
        public var publishedDate: Date?
        public var duration: Double?
        public var thumbnailUrl: URL?
        public var mediaUrl: URL?
        public var episodeUrl: URL?
        public var episodeDescription: String?
        public var chaptersUrl: URL?
        public var isAudioOnly: Bool?
        public var updatedDate: Date

        public init(episodeId: String, feedUrl: URL, title: String, updatedDate: Date = .now) {
            self.episodeId = episodeId
            self.feedUrl = feedUrl
            self.title = title
            self.updatedDate = updatedDate
        }
    }
}
