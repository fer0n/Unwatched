//
//  VersionedSchema.swift
//  Unwatched
//

import SwiftData
import SwiftUI

enum UnwatchedSchemaV1p1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 1, 0)

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
            try? context.delete(model: UnwatchedSchemaV1.CachedImage.self)
            try? context.save()
        }, didMigrate: nil
    )

    static var stages: [MigrationStage] {
        [migrateV1toV1p1]
    }
}

// MARK: CachedImageSchema

enum CachedImageSchemaV1p1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 1, 0)

    static var models: [any PersistentModel.Type] {
        [CachedImage.self]
    }
}

enum CachedImageMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [CachedImageSchemaV1.self, CachedImageSchemaV1p1.self]
    }

    static let migrateCachedImageV1toV1p1 = MigrationStage.custom(
        fromVersion: CachedImageSchemaV1.self,
        toVersion: CachedImageSchemaV1p1.self,
        willMigrate: { context in
            // clear cache
            try? context.delete(model: CachedImageSchemaV1.CachedImage.self)
            try? context.save()
        }, didMigrate: nil
    )

    static var stages: [MigrationStage] {
        [migrateCachedImageV1toV1p1]
    }
}
