//
//  UnwatchedSchemaV1p14.swift
//  Unwatched
//

import SwiftData
import SwiftUI

enum UnwatchedSchemaV1p14: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 14, 0)

    static var models: [any PersistentModel.Type] {
        [
            Video.self,
            Subscription.self,
            QueueEntry.self,
            InboxEntry.self,
            Chapter.self,
            WatchTimeEntry.self
        ]
    }
}
