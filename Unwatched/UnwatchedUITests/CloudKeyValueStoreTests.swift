//
//  CloudKeyValueStoreTests.swift
//  UnwatchedUITests
//

import XCTest
import UnwatchedShared

/// Stands in for `NSUbiquitousKeyValueStore`. `unavailable` is the state that made premium vanish
/// on a device with iCloud switched off for the app: reads answer nothing and writes go nowhere,
/// with no error either way.
private final class FakeCloud: KeyValueStoring {
    var values: [String: Any]
    var unavailable = false

    init(_ values: [String: Any] = [:]) {
        self.values = values
    }

    func object(forKey aKey: String) -> Any? {
        unavailable ? nil : values[aKey]
    }

    func set(_ anObject: Any?, forKey aKey: String) {
        guard !unavailable else { return }
        values[aKey] = anObject
    }

    func removeObject(forKey aKey: String) {
        guard !unavailable else { return }
        values.removeValue(forKey: aKey)
    }

    func longLong(forKey aKey: String) -> Int64 {
        (object(forKey: aKey) as? NSNumber)?.int64Value ?? 0
    }

    func bool(forKey aKey: String) -> Bool {
        (object(forKey: aKey) as? NSNumber)?.boolValue ?? false
    }

    var dictionaryRepresentation: [String: Any] {
        unavailable ? [:] : values
    }
}

final class CloudKeyValueStoreTests: XCTestCase {
    private var mirror: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "CloudKeyValueStoreTests.\(UUID().uuidString)"
        mirror = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        mirror.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeStore(_ cloud: FakeCloud) -> CloudKeyValueStore {
        CloudKeyValueStore(cloud: cloud, mirror: mirror)
    }

    /// The reported bug: premium was set long before the mirror existed, so only a seed can save
    /// it from the next time iCloud goes away.
    func testSeededValueSurvivesICloudTurningOff() {
        let cloud = FakeCloud([Const.unwatchedPremiumAcknowledged: true])
        let store = makeStore(cloud)

        store.seedMirror()
        cloud.unavailable = true

        XCTAssertTrue(store.bool(forKey: Const.unwatchedPremiumAcknowledged))
    }

    /// The second half of the bug: without a mirror the write went nowhere, so the trial button
    /// kept flipping back.
    func testWriteWithoutICloudSticks() {
        let cloud = FakeCloud()
        cloud.unavailable = true
        let store = makeStore(cloud)

        store.set(true, forKey: Const.unwatchedPremiumAcknowledged)

        XCTAssertTrue(store.bool(forKey: Const.unwatchedPremiumAcknowledged))
    }

    func testICloudWinsOverTheMirror() {
        let cloud = FakeCloud()
        let store = makeStore(cloud)

        store.set(1, forKey: Const.autoDeleteInboxVideosLimit)
        cloud.values[Const.autoDeleteInboxVideosLimit] = 2

        XCTAssertEqual(store.longLong(forKey: Const.autoDeleteInboxVideosLimit), 2)
    }

    /// An unreachable store reads as empty, which must not be mistaken for the user clearing it.
    func testSeedingFromAnUnavailableStoreKeepsTheMirror() {
        let cloud = FakeCloud([Const.skipChapterText: "ad"])
        let store = makeStore(cloud)
        store.seedMirror()

        cloud.unavailable = true
        store.seedMirror()

        XCTAssertEqual(store.string(forKey: Const.skipChapterText), "ad")
    }

    /// A removal on another device does have to arrive, though — that's what the changed-keys
    /// list from iCloud is for.
    func testExternalRemovalClearsTheMirror() {
        let cloud = FakeCloud([Const.skipChapterText: "ad"])
        let store = makeStore(cloud)
        store.seedMirror()

        cloud.values.removeValue(forKey: Const.skipChapterText)
        store.refreshMirror(forKeys: [Const.skipChapterText])

        XCTAssertNil(store.string(forKey: Const.skipChapterText))
    }

    func testRemoveClearsBothStores() {
        let cloud = FakeCloud()
        let store = makeStore(cloud)
        store.set(true, forKey: Const.youtubePremium)

        store.removeObject(forKey: Const.youtubePremium)

        XCTAssertNil(store.object(forKey: Const.youtubePremium))
        XCTAssertNil(cloud.values[Const.youtubePremium])
    }

    /// The real singleton, in a process where the ubiquitous store has no entitlement to write
    /// through — the same state the device that reported this was in.
    func testSharedStoreKeepsValuesWithoutICloud() {
        let key = "CloudKeyValueStoreTests.roundTrip"
        defer { CloudKeyValueStore.shared.removeObject(forKey: key) }

        CloudKeyValueStore.shared.set(true, forKey: key)

        XCTAssertTrue(CloudKeyValueStore.shared.bool(forKey: key))
    }

    /// Mirrored values are namespaced: several synced keys still exist under the same name in
    /// `UserDefaults`, and a local setting must not be able to shadow a synced one.
    func testMirrorDoesNotWriteUnprefixedKeys() {
        let store = makeStore(FakeCloud())

        store.set(true, forKey: Const.youtubePremium)

        XCTAssertNil(mirror.object(forKey: Const.youtubePremium))
    }
}
