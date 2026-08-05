//
//  CachedImageSchemaV2p1.swift
//  UnwatchedShared
//

import SwiftData
import SwiftUI

public enum CachedImageSchemaV2p1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(2, 1, 0)

    public static var models: [any PersistentModel.Type] {
        [CachedImage.self, Transcript.self]
    }
}
