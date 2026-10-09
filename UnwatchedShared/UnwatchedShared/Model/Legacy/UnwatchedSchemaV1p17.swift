//
//  UnwatchedSchemaV1p17.swift
//  Unwatched
//

import SwiftData
import SwiftUI

public enum UnwatchedSchemaV1p17: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 17, 0)

    public static var models: [any PersistentModel.Type] {
        [
            Video.self,
            Subscription.self,
            QueueEntry.self,
            InboxEntry.self,
            Chapter.self,
            WatchTimeEntry.self,
            Tag.self
        ]
    }
}
