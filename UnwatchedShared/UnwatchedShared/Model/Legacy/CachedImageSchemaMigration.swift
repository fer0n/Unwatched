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
            CachedImageSchemaV1p2.self
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

    public static var stages: [MigrationStage] {
        [
            migrateCachedImageV1toV1p1,
            migrateCachedImageV1p1toV1p2
        ]
    }
}
