//
//  VersionedSchema.swift
//  Unwatched
//

import SwiftData
import SwiftUI

enum UnwatchedSchemaV1p1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 1, 0)

    static var models: [any PersistentModel.Type] {
        [
            Video.self,
            Subscription.self,
            QueueEntry.self,
            WatchEntry.self,
            InboxEntry.self,
            Chapter.self
        ]
    }
}

enum UnwatchedMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [UnwatchedSchemaV1.self, UnwatchedSchemaV1p1.self]
    }

    static let migrateV1toV1p1 = MigrationStage.custom(
        fromVersion: UnwatchedSchemaV1.self,
        toVersion: UnwatchedSchemaV1p1.self,
        willMigrate: { context in
            // remove duplicates then save
            try? context.delete(model: UnwatchedSchemaV1.CachedImage.self)
            let container = context.container
            _ = CleanupService.cleanupDuplicatesAndInboxDate(container, onlyIfDuplicateEntriesExist: false)
            try? context.save()
        }, didMigrate: nil
    )

    static var stages: [MigrationStage] {
        [migrateV1toV1p1]
    }
}
