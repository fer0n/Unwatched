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
}
