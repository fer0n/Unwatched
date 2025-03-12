//
//  VersionedSchema.swift
//  Unwatched
//

import SwiftData
import SwiftUI

public enum UnwatchedMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
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

    public static var migrateV1p2toV1p3 = MigrationStage.custom(
        fromVersion: UnwatchedSchemaV1p2.self,
        toVersion: UnwatchedSchemaV1p3.self,
        willMigrate: nil,
        didMigrate: nil
    )
    
    public static var migrateV1p3toV1p4 = MigrationStage.custom(
        fromVersion: UnwatchedSchemaV1p3.self,
        toVersion: UnwatchedSchemaV1p4.self,
        willMigrate: { context in
            migrateHideShortsSetting()
        },
        didMigrate: { context in
            migrateHideShortsSetting()
        }
    )
    
    private static func migrateHideShortsSetting() {
        if UserDefaults.standard.object(forKey: Const.defaultShortsSetting) == nil {
            let hideShorts = UserDefaults.standard.bool(forKey: Const.hideShorts)
            let shortSetting = hideShorts ? ShortsSetting.hide : ShortsSetting.show
            UserDefaults.standard.setValue(shortSetting.rawValue, forKey: Const.defaultShortsSetting)
        }
    }
    
    public static var migrateV1p4toV1p5 = MigrationStage.custom(
        fromVersion: UnwatchedSchemaV1p4.self,
        toVersion: UnwatchedSchemaV1p5.self,
        willMigrate: nil,
        didMigrate: nil
    )
    
    public static var migrateV1p5toV1p6 = MigrationStage.custom(
        fromVersion: UnwatchedSchemaV1p5.self,
        toVersion: UnwatchedSchemaV1p6.self,
        willMigrate: nil,
        didMigrate: nil
    )

    public static var stages: [MigrationStage] {
        [
            migrateV1toV1p1,
            migrateV1p1toV1p2,
            migrateV1p2toV1p3,
            migrateV1p3toV1p4,
            migrateV1p4toV1p5,
            migrateV1p5toV1p6
        ]
    }
}
