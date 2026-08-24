//
//  VersionedSchema.swift
//  Unwatched
//

import SwiftData
import SwiftUI

public enum UnwatchedMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [
            UnwatchedSchemaV1.self,
            UnwatchedSchemaV1p1.self,
            UnwatchedSchemaV1p2.self,
            UnwatchedSchemaV1p3.self,
            UnwatchedSchemaV1p4.self,
            UnwatchedSchemaV1p5.self,
            UnwatchedSchemaV1p6.self,
            UnwatchedSchemaV1p7.self,
            UnwatchedSchemaV1p8.self,
            UnwatchedSchemaV1p9.self,
            UnwatchedSchemaV1p10.self,
            UnwatchedSchemaV1p11.self,
            UnwatchedSchemaV1p12.self,
            UnwatchedSchemaV1p13.self,
            UnwatchedSchemaV1p14.self,
            UnwatchedSchemaV1p15.self,
        ]
    }
    
    static let migrateV1toV1p1 = MigrationStage.custom(
        fromVersion: UnwatchedSchemaV1.self,
        toVersion: UnwatchedSchemaV1p1.self,
        willMigrate: { context in
            try? context.delete(model: UnwatchedSchemaV1.CachedImage.self)
            try? context.save()
        }, didMigrate: nil
    )
    
    /// Keyed by `youtubeId`, not `PersistentIdentifier`: the identifiers handed out before the
    /// migration don't resolve to the post-migration models, so `context.model(for:)` used to
    /// return something that never cast to a `Video` and every watch date was dropped.
    static var watchedDates = [String: Date]()
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
                    UnwatchedMigrationPlan.watchedDates[video.youtubeId] = mostRecentWatchDate
                }
                try? context.delete(model: UnwatchedSchemaV1.WatchEntry.self)
            }

            try? context.save()
        },
        didMigrate: { context in
            let fetch = FetchDescriptor<UnwatchedSchemaV1p2.Video>()
            if let videos = try? context.fetch(fetch) {
                for video in videos {
                    if let date = UnwatchedMigrationPlan.watchedDates[video.youtubeId] {
                        video.watchedDate = date
                    }
                }
            }
            try? context.save()
            UnwatchedMigrationPlan.watchedDates = [:]
        }
    )
    
    public static let migrateV1p2toV1p3 = MigrationStage.lightweight(
        fromVersion: UnwatchedSchemaV1p2.self,
        toVersion: UnwatchedSchemaV1p3.self
    )
    
    /// The `hideShorts` -> `defaultShortsSetting` conversion this used to carry now runs from
    /// `SettingsMigration`; it only ever touched `UserDefaults`.
    public static let migrateV1p3toV1p4 = MigrationStage.lightweight(
        fromVersion: UnwatchedSchemaV1p3.self,
        toVersion: UnwatchedSchemaV1p4.self
    )

    public static let migrateV1p4toV1p5 = MigrationStage.lightweight(
        fromVersion: UnwatchedSchemaV1p4.self,
        toVersion: UnwatchedSchemaV1p5.self
    )
    
    public static let migrateV1p5toV1p6 = MigrationStage.lightweight(
        fromVersion: UnwatchedSchemaV1p5.self,
        toVersion: UnwatchedSchemaV1p6.self
    )
    
    /// Carried between this stage's two passes on disk rather than in memory: if the app is
    /// killed between `willMigrate` and `didMigrate`, an in-memory dictionary takes the pending
    /// placements with it and `DataProvider`'s recovery pass has nothing left to apply.
    static var subPlaceVideosIn: [String: Int] {
        get { UserDefaults.standard.dictionary(forKey: pendingVideoPlacementKey) as? [String: Int] ?? [:] }
        set {
            if newValue.isEmpty {
                UserDefaults.standard.removeObject(forKey: pendingVideoPlacementKey)
            } else {
                UserDefaults.standard.set(newValue, forKey: pendingVideoPlacementKey)
            }
        }
    }
    private static let pendingVideoPlacementKey = "migrationPendingVideoPlacement"

    public static let migrateV1p6toV1p7 = MigrationStage.custom(
        fromVersion: UnwatchedSchemaV1p6.self,
        toVersion: UnwatchedSchemaV1p7.self,
        willMigrate: {
            context in
            let fetch = FetchDescriptor<UnwatchedSchemaV1p6.Subscription>()
            var pending = [String: Int]()
            if let subs = try? context.fetch(fetch) {
                for sub in subs {
                    if let channelId = sub.youtubeChannelId {
                        pending[channelId] = sub.placeVideosIn.rawValue
                    }
                }
            }
            UnwatchedMigrationPlan.subPlaceVideosIn = pending
        },
        didMigrate: { context in
            let pending = UnwatchedMigrationPlan.subPlaceVideosIn
            let fetch = FetchDescriptor<UnwatchedSchemaV1p7.Subscription>()
            if let subs = try? context.fetch(fetch) {
                for sub in subs {
                    if let channelId = sub.youtubeChannelId,
                       let videoPlacement = pending[channelId] {
                        sub._videoPlacement = videoPlacement
                    }
                }
            }
            try? context.save()
            UnwatchedMigrationPlan.subPlaceVideosIn = [:]
        }
    )

    /// Same write-back as the stage's `didMigrate`, against the current `Subscription`, for
    /// `DataProvider`'s recovery pass.
    public static func migrateV1p6toV1p7DidMigrate(_ context: ModelContext) {
        let pending = UnwatchedMigrationPlan.subPlaceVideosIn
        let fetch = FetchDescriptor<Subscription>()
        if let subs = try? context.fetch(fetch) {
            for sub in subs {
                if let channelId = sub.youtubeChannelId,
                   let videoPlacement = pending[channelId] {
                    sub._videoPlacement = videoPlacement
                }
            }
        }
        try? context.save()
        UnwatchedMigrationPlan.subPlaceVideosIn = [:]
    }

    /// Still custom: unlike the other settings conversions this one has no idempotent guard —
    /// it has to run exactly at this boundary, or it would overwrite a `useNoCookieUrl` the user
    /// has since changed.
    public static let migrateV1p7toV1p8 = MigrationStage.custom(
        fromVersion: UnwatchedSchemaV1p7.self,
        toVersion: UnwatchedSchemaV1p8.self,
        willMigrate: nil,
        didMigrate: { _ in
            let enableYtWatchHistory = "enableYtWatchHistory".bool ?? true
            UserDefaults.standard.setValue(!enableYtWatchHistory, forKeyPath: Const.useNoCookieUrl)
        }
    )
    
    public static let migrateV1p8toV1p9 = MigrationStage.lightweight(
        fromVersion: UnwatchedSchemaV1p8.self,
        toVersion: UnwatchedSchemaV1p9.self
    )
    
    /// The `UserDefaults` -> `NSUbiquitousKeyValueStore` move this used to carry now runs from
    /// `SettingsMigration`; it only ever touched settings.
    public static let migrateV1p9toV1p10 = MigrationStage.lightweight(
        fromVersion: UnwatchedSchemaV1p9.self,
        toVersion: UnwatchedSchemaV1p10.self
    )

    public static let migrateV1p10toV1p11 = MigrationStage.lightweight(
        fromVersion: UnwatchedSchemaV1p10.self,
        toVersion: UnwatchedSchemaV1p11.self
    )
    
    public static let migrateV1p11toV1p12 = MigrationStage.lightweight(
        fromVersion: UnwatchedSchemaV1p11.self,
        toVersion: UnwatchedSchemaV1p12.self
    )
    
    public static let migrateV1p12toV1p13 = MigrationStage.lightweight(
        fromVersion: UnwatchedSchemaV1p12.self,
        toVersion: UnwatchedSchemaV1p13.self
    )
    
    public static let migrateV1p13toV1p14 = MigrationStage.lightweight(
        fromVersion: UnwatchedSchemaV1p13.self,
        toVersion: UnwatchedSchemaV1p14.self
    )

    /// Adds `Tag`, the podcast columns on `Video`/`Subscription` and `skipIntroSeconds`.
    public static let migrateV1p14toV1p15 = MigrationStage.lightweight(
        fromVersion: UnwatchedSchemaV1p14.self,
        toVersion: UnwatchedSchemaV1p15.self
    )

    public static var stages: [MigrationStage] {
        [
            migrateV1toV1p1,
            migrateV1p1toV1p2,
            migrateV1p2toV1p3,
            migrateV1p3toV1p4,
            migrateV1p4toV1p5,
            migrateV1p5toV1p6,
            migrateV1p6toV1p7,
            migrateV1p7toV1p8,
            migrateV1p8toV1p9,
            migrateV1p9toV1p10,
            migrateV1p10toV1p11,
            migrateV1p11toV1p12,
            migrateV1p12toV1p13,
            migrateV1p13toV1p14,
            migrateV1p14toV1p15
        ]
    }
}
