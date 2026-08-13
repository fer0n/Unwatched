//
//  CachedImageSchemaV1p1.swift
//  UnwatchedShared
//

import SwiftData

public enum CachedImageMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [
            CachedImageSchemaV1.self,
            CachedImageSchemaV1p1.self,
            CachedImageSchemaV1p2.self,
            CachedImageSchemaV2.self,
            CachedImageSchemaV2p1.self,
            CachedImageSchemaV2p2.self,
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

    static let migrateCachedImageV1p1toV1p2 = MigrationStage.custom(
        fromVersion: CachedImageSchemaV1p1.self,
        toVersion: CachedImageSchemaV1p2.self,
        willMigrate: nil,
        didMigrate: nil
    )
    
    static let migrateCachedImageV1p2toV2 = MigrationStage.custom(
        fromVersion: CachedImageSchemaV1p2.self,
        toVersion: CachedImageSchemaV2.self,
        willMigrate: nil,
        didMigrate: nil
    )
    
    static let migrateCachedImageV2toV2p1 = MigrationStage.custom(
        fromVersion: CachedImageSchemaV2.self,
        toVersion: CachedImageSchemaV2p1.self,
        willMigrate: nil,
        didMigrate: nil
    )

    /// Adds `CachedChapters`, same as V2 -> V2p1 added `Transcript`: a new entity, nothing to
    /// convert.
    static let migrateCachedImageV2p1toV2p2 = MigrationStage.custom(
        fromVersion: CachedImageSchemaV2p1.self,
        toVersion: CachedImageSchemaV2p2.self,
        willMigrate: nil,
        didMigrate: nil
    )

    public static var stages: [MigrationStage] {
        [
            migrateCachedImageV1toV1p1,
            migrateCachedImageV1p1toV1p2,
            migrateCachedImageV1p2toV2,
            migrateCachedImageV2toV2p1,
            migrateCachedImageV2p1toV2p2
        ]
    }
}
