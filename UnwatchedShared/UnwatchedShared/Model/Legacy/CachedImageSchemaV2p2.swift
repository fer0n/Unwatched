//
//  CachedImageSchemaV2p2.swift
//  UnwatchedShared
//

import SwiftData
import SwiftUI

public enum CachedImageSchemaV2p2: VersionedSchema {
    public static let versionIdentifier = Schema.Version(2, 2, 0)

    public static var models: [any PersistentModel.Type] {
        [CachedImage.self, Transcript.self, CachedChapters.self]
    }
}
