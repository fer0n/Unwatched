//
//  SettingsMigrationTests.swift
//  UnwatchedUITests
//

import XCTest
import UnwatchedShared

private final class MemoryStore: SettingsStore {
    private var values: [String: Any] = [:]

    init(_ values: [String: Any] = [:]) {
        self.values = values
    }

    func object(forKey key: String) -> Any? { values[key] }
    func set(_ value: Any?, forKey key: String) { values[key] = value }
    func removeObject(forKey key: String) { values[key] = nil }
}

/// `SettingsMigration` runs on every launch, so the thing worth proving is that it stays a no-op
/// once it has done its work — an unguarded step would reset a setting the user has since changed.
///
/// Uses in-memory stores rather than the real ones: `NSUbiquitousKeyValueStore` drops writes
/// without the iCloud entitlement, and the tests would otherwise mutate the developer's own
/// settings.
final class SettingsMigrationTests: XCTestCase {

    /// A fresh install has nothing to convert and has to keep the registered default.
    func testFreshInstallIsUntouched() {
        let defaults = MemoryStore()
        let cloud = MemoryStore()

        SettingsMigration.run(defaults: defaults, cloud: cloud)

        XCTAssertNil(defaults.object(forKey: Const.defaultShortsSetting))
        XCTAssertNil(cloud.object(forKey: Const.defaultShortsSetting))
    }

    func testHideShortsBecomesShortsSetting() {
        let defaults = MemoryStore([Const.hideShorts: true])
        let cloud = MemoryStore()

        SettingsMigration.run(defaults: defaults, cloud: cloud)

        XCTAssertEqual(cloud.object(forKey: Const.defaultShortsSetting) as? Int, ShortsSetting.hide.rawValue)
        XCTAssertNil(defaults.object(forKey: Const.hideShorts), "legacy key should be cleared")
    }

    func testHideShortsFalseBecomesShow() {
        let defaults = MemoryStore([Const.hideShorts: false])
        let cloud = MemoryStore()

        SettingsMigration.run(defaults: defaults, cloud: cloud)

        XCTAssertEqual(cloud.object(forKey: Const.defaultShortsSetting) as? Int, ShortsSetting.show.rawValue)
    }

    /// An install that already has the setting keeps it — the legacy value must not win.
    func testExistingShortsSettingIsNotOverwritten() {
        let defaults = MemoryStore([Const.hideShorts: true])
        let cloud = MemoryStore([Const.defaultShortsSetting: ShortsSetting.show.rawValue])

        SettingsMigration.run(defaults: defaults, cloud: cloud)

        XCTAssertEqual(cloud.object(forKey: Const.defaultShortsSetting) as? Int, ShortsSetting.show.rawValue)
    }

    func testSyncedSettingsMoveToKeyValueStore() {
        let defaults = MemoryStore([
            Const.skipChapterText: "skip me",
            Const.youtubePremium: true
        ])
        let cloud = MemoryStore()

        SettingsMigration.run(defaults: defaults, cloud: cloud)

        XCTAssertEqual(cloud.object(forKey: Const.skipChapterText) as? String, "skip me")
        XCTAssertEqual(cloud.object(forKey: Const.youtubePremium) as? Bool, true)
        XCTAssertNil(defaults.object(forKey: Const.skipChapterText))
        XCTAssertNil(defaults.object(forKey: Const.youtubePremium))
    }

    /// The step that most needs a guard: without one, a stale `UserDefaults` value would
    /// overwrite the synced setting on every launch.
    func testSyncedSettingsAreNotOverwrittenOnLaterRuns() {
        let defaults = MemoryStore([Const.skipChapterText: "original"])
        let cloud = MemoryStore()
        SettingsMigration.run(defaults: defaults, cloud: cloud)

        cloud.set("changed by user", forKey: Const.skipChapterText)
        defaults.set("stale", forKey: Const.skipChapterText)
        SettingsMigration.run(defaults: defaults, cloud: cloud)

        XCTAssertEqual(cloud.object(forKey: Const.skipChapterText) as? String, "changed by user")
    }

    /// Repeated launches must not undo the first run's work.
    func testRepeatedRunsAreStable() {
        let defaults = MemoryStore([Const.hideShorts: true, Const.skipChapterText: "keep"])
        let cloud = MemoryStore()

        for _ in 0..<3 {
            SettingsMigration.run(defaults: defaults, cloud: cloud)
        }

        XCTAssertEqual(cloud.object(forKey: Const.defaultShortsSetting) as? Int, ShortsSetting.hide.rawValue)
        XCTAssertEqual(cloud.object(forKey: Const.skipChapterText) as? String, "keep")
        XCTAssertNil(defaults.object(forKey: Const.defaultShortsSetting))
    }
}
