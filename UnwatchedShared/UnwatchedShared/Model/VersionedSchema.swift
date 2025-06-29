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
        willMigrate: { _ in
            migrateHideShortsSetting()
        },
        didMigrate: { _ in
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

    static var subPlaceVideosIn = [String: Int]()
    public static var migrateV1p6toV1p7 = MigrationStage.custom(
        fromVersion: UnwatchedSchemaV1p6.self,
        toVersion: UnwatchedSchemaV1p7.self,
        willMigrate: {
            context in
            let fetch = FetchDescriptor<UnwatchedSchemaV1p6.Subscription>()
            UnwatchedMigrationPlan.subPlaceVideosIn = [:]
            if let subs = try? context.fetch(fetch) {
                for sub in subs {
                    if let channelId = sub.youtubeChannelId {
                        UnwatchedMigrationPlan.subPlaceVideosIn[channelId] = sub.placeVideosIn.rawValue
                    }
                }
            }
        },
        didMigrate: { context in
            let fetch = FetchDescriptor<UnwatchedSchemaV1p7.Subscription>()
            if let subs = try? context.fetch(fetch) {
                for sub in subs {
                    if let channelId = sub.youtubeChannelId,
                       let videoPlacement = UnwatchedMigrationPlan.subPlaceVideosIn[channelId] {
                        sub._videoPlacement = videoPlacement
                    }
                }
            }
            try? context.save()
            UnwatchedMigrationPlan.subPlaceVideosIn = [:]
        }
    )
    public static func migrateV1p6toV1p7DidMigrate(_ context: ModelContext) {
        let fetch = FetchDescriptor<Subscription>()
        if let subs = try? context.fetch(fetch) {
            for sub in subs {
                if let channelId = sub.youtubeChannelId,
                   let videoPlacement = UnwatchedMigrationPlan.subPlaceVideosIn[channelId] {
                    sub._videoPlacement = videoPlacement
                }
            }
        }
        try? context.save()
        UnwatchedMigrationPlan.subPlaceVideosIn = [:]
    }

    public static var migrateV1p7toV1p8 = MigrationStage.custom(
        fromVersion: UnwatchedSchemaV1p7.self,
        toVersion: UnwatchedSchemaV1p8.self,
        willMigrate: nil,
        didMigrate: { _ in
            let enableYtWatchHistory = "enableYtWatchHistory".bool ?? true
            UserDefaults.standard.setValue(!enableYtWatchHistory, forKeyPath: Const.useNoCookieUrl)
        }
    )

    public static var migrateV1p8toV1p9 = MigrationStage.custom(
        fromVersion: UnwatchedSchemaV1p8.self,
        toVersion: UnwatchedSchemaV1p9.self,
        willMigrate: nil,
        didMigrate: nil
    )

    public static var migrateV1p9toV1p10 = MigrationStage.custom(
        fromVersion: UnwatchedSchemaV1p9.self,
        toVersion: UnwatchedSchemaV1p10.self,
        willMigrate: { _ in
            migrateV1p9toV1p10DidMigrate()
        },
        didMigrate: { _ in
            migrateV1p9toV1p10DidMigrate()
        }
    )
    public static func migrateV1p9toV1p10DidMigrate() {
        Log.info("Migrating UserDefaults to iCloud KeyValueStore")
        if UserDefaults.standard.bool(forKey: "v1p9toV1p10DidMigrate") {
            Log.info("Migration already done")
            return
        }
        if let value = UserDefaults.standard.value(forKey: Const.defaultShortsSetting) as? Int64 {
            Log.info("Migrate: defaultShortsSetting \(value)")
            NSUbiquitousKeyValueStore.default.set(value, forKey: Const.defaultShortsSetting)
            UserDefaults.standard.removeObject(forKey: Const.defaultShortsSetting)
        }
        if let value = UserDefaults.standard.value(forKey: Const.skipChapterText) as? String {
            Log.info("Migrate: skipChapterText \(value)")
            NSUbiquitousKeyValueStore.default.set(value, forKey: Const.skipChapterText)
            UserDefaults.standard.removeObject(forKey: Const.skipChapterText)
        }
        if let value = UserDefaults.standard.value(forKey: Const.mergeSponsorBlockChapters) as? Bool {
            Log.info("Migrate: mergeSponsorBlockChapters \(value)")
            NSUbiquitousKeyValueStore.default.set(value, forKey: Const.mergeSponsorBlockChapters)
            UserDefaults.standard.removeObject(forKey: Const.mergeSponsorBlockChapters)
        }
        if let value = UserDefaults.standard.value(forKey: Const.youtubePremium) as? Bool {
            Log.info("Migrate: youtubePremium \(value)")
            NSUbiquitousKeyValueStore.default.set(value, forKey: Const.youtubePremium)
            UserDefaults.standard.removeObject(forKey: Const.youtubePremium)
        }
        if let value = UserDefaults.standard.value(forKey: Const.skipSponsorSegments) as? Bool {
            Log.info("Migrate: skipSponsorSegments \(value)")
            NSUbiquitousKeyValueStore.default.set(value, forKey: Const.skipSponsorSegments)
            UserDefaults.standard.removeObject(forKey: Const.skipSponsorSegments)
        }
        UserDefaults.standard.set(true, forKey: "v1p9toV1p10DidMigrate")
    }

    public static var migrateV1p10toV1p11 = MigrationStage.custom(
        fromVersion: UnwatchedSchemaV1p10.self,
        toVersion: UnwatchedSchemaV1p11.self,
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
            migrateV1p5toV1p6,
            migrateV1p6toV1p7,
            migrateV1p7toV1p8,
            migrateV1p8toV1p9,
            migrateV1p9toV1p10,
            migrateV1p10toV1p11
        ]
    }
}
