//
//  UnwatchedSchemaV1.swift
//  Unwatched
//

import SwiftData
import SwiftUI

enum UnwatchedSchemaV1p12: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 12, 0)

    static var models: [any PersistentModel.Type] {
        [
            Video.self,
            Subscription.self,
            QueueEntry.self,
            InboxEntry.self,
            Chapter.self
        ]
    }
}
