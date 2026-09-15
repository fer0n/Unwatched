//
//  CachedImageSchemaV2p3.swift
//  UnwatchedShared
//

import SwiftData
import SwiftUI

public enum CachedImageSchemaV2p3: VersionedSchema {
    public static let versionIdentifier = Schema.Version(2, 3, 0)

    public static var models: [any PersistentModel.Type] {
        [CachedImage.self, Transcript.self, CachedChapters.self, CachedEpisode.self]
    }
}
