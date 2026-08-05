//
//  SettingsMigration.swift
//  UnwatchedShared
//

import Foundation

/// The subset of `UserDefaults` / `NSUbiquitousKeyValueStore` that `SettingsMigration` needs.
///
/// Exists so the migration can be exercised in tests: the key-value store silently drops writes
/// without the iCloud entitlement, so a test process can't assert against the real one.
public protocol SettingsStore: AnyObject {
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
    func removeObject(forKey key: String)
}

extension UserDefaults: SettingsStore {}
extension NSUbiquitousKeyValueStore: SettingsStore {}

/// One-off settings conversions that used to ride along on SwiftData migration stages.
///
/// They never touched the store, and a migration stage is an unreliable place to run them: the
/// closures don't fire for every store configuration, which is why each one ended up duplicated
/// across both `willMigrate` and `didMigrate` and then run a third time from `DataProvider`.
///
/// Each step is instead guarded by its own state, so `run()` is safe to call on every launch and
/// the stages it replaces can stay lightweight.
public enum SettingsMigration {
    public static func run(
        defaults: SettingsStore = UserDefaults.standard,
        cloud: SettingsStore = NSUbiquitousKeyValueStore.default
    ) {
        migrateHideShorts(defaults, cloud)
        migrateSyncedSettingsToKeyValueStore(defaults, cloud)
    }

    /// V1p3 -> V1p4: the `hideShorts` bool became the three-state `defaultShortsSetting`.
    ///
    /// Keyed off the source rather than the destination, and clears it afterwards: a fresh
    /// install has no `hideShorts` to convert and must keep the registered default, and once
    /// `migrateSyncedSettingsToKeyValueStore` has moved the destination out of `defaults`, a
    /// destination-only guard would let this write a stale value back on every launch.
    private static func migrateHideShorts(_ defaults: SettingsStore, _ cloud: SettingsStore) {
        guard let hideShorts = defaults.object(forKey: Const.hideShorts) as? Bool else {
            return
        }
        let alreadySet = defaults.object(forKey: Const.defaultShortsSetting) != nil
            || cloud.object(forKey: Const.defaultShortsSetting) != nil
        if !alreadySet {
            let setting = hideShorts ? ShortsSetting.hide : ShortsSetting.show
            defaults.set(setting.rawValue, forKey: Const.defaultShortsSetting)
        }
        defaults.removeObject(forKey: Const.hideShorts)
    }

    /// V1p9 -> V1p10: settings that should follow the user across devices moved from
    /// `UserDefaults` to `NSUbiquitousKeyValueStore`.
    private static func migrateSyncedSettingsToKeyValueStore(
        _ defaults: SettingsStore,
        _ cloud: SettingsStore
    ) {
        if defaults.object(forKey: didMigrateToKeyValueStore) as? Bool == true {
            return
        }
        Log.info("Migrating UserDefaults to iCloud KeyValueStore")

        for key in syncedKeys {
            guard let value = defaults.object(forKey: key) else { continue }
            Log.info("Migrate: \(key)")
            cloud.set(value, forKey: key)
            defaults.removeObject(forKey: key)
        }

        defaults.set(true, forKey: didMigrateToKeyValueStore)
    }

    private static let didMigrateToKeyValueStore = "v1p9toV1p10DidMigrate"

    private static let syncedKeys = [
        Const.defaultShortsSetting,
        Const.skipChapterText,
        Const.mergeSponsorBlockChapters,
        Const.youtubePremium,
        Const.skipSponsorSegments
    ]
}
