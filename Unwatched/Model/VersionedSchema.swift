//
//  VersionedSchema.swift
//  Unwatched
//

import SwiftData
import SwiftUI

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

    static var watchedDates = [PersistentIdentifier: Date]()
    static let migrateV1p1toV1p2 = MigrationStage.custom(
        fromVersion: UnwatchedSchemaV1p1.self,
        toVersion: UnwatchedSchemaV1p2.self,
        willMigrate: {
            context in
            let fetch = FetchDescriptor<UnwatchedSchemaV1p1.Video>(predicate: #Predicate { $0.watched == true })
            if let videos = try? context.fetch(fetch) {
                for video in videos {
                    // most recent video watch entry
                    guard let mostRecentWatchDate = video.watchEntries?.max(by: {
                        $0.date ?? .distantPast < $1.date ?? .distantPast
                    })?.date else {
                        continue
                    }
                    UnwatchedMigrationPlan.watchedDates[video.persistentModelID] = mostRecentWatchDate
                }
                try? context.delete(model: UnwatchedSchemaV1.WatchEntry.self)
            }

            try? context.save()
        },
        didMigrate: { context in
            for (videoId, date) in UnwatchedMigrationPlan.watchedDates {
                if let video = context.model(for: videoId) as? Video {
                    video.watchedDate = date
                }
            }
            try? context.save()
        }
    )

    static let migrateV1p2toV1p3 = MigrationStage.custom(
        fromVersion: UnwatchedSchemaV1p2.self,
        toVersion: UnwatchedSchemaV1p3.self,
        willMigrate: nil,
        didMigrate: nil
    )

    static var stages: [MigrationStage] {
        [
            migrateV1toV1p1,
            migrateV1p1toV1p2,
            migrateV1p2toV1p3
        ]
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
        [
            CachedImageSchemaV1.self,
            CachedImageSchemaV1p1.self
        ]
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
