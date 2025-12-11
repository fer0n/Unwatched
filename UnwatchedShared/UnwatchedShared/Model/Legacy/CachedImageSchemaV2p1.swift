//
//  CachedImageSchemaV2p1.swift
//  UnwatchedShared
//

import SwiftData
import SwiftUI

enum CachedImageSchemaV2p1: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 1, 0)

    static var models: [any PersistentModel.Type] {
        [CachedImage.self, Transcript.self]
    }
}
