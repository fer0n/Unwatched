//
//  CachedImageSchemaV1p1.swift
//  UnwatchedShared
//

import SwiftData



enum CachedImageSchemaV1p1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 1, 0)

    static var models: [any PersistentModel.Type] {
        [CachedImage.self]
    }
}

public enum CachedImageMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
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

    public static var stages: [MigrationStage] {
        [migrateCachedImageV1toV1p1]
    }
}
