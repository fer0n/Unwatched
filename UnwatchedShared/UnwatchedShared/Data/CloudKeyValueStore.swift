//
//  CloudKeyValueStore.swift
//  UnwatchedShared
//

import Foundation

/// `NSUbiquitousKeyValueStore` with a local mirror, so synced settings survive iCloud being off.
///
/// The ubiquitous store only answers while iCloud is enabled for the app: with it switched off,
/// reads come back nil and writes are dropped without an error. Every synced setting then falls
/// back to its registered default and edits don't stick — most visibly premium, which is nothing
/// but a bool in that store, so a device without iCloud can neither keep it nor turn it back on.
///
/// iCloud stays the source of truth: a value it returns is always the newer one, and the mirror
/// is consulted only when it has no answer at all. The mirror is never cleared wholesale, because
/// an empty ubiquitous store means "unavailable" as often as it means "empty"; a key leaves the
/// mirror only when it's removed explicitly or when iCloud reports it as externally removed.
public final class CloudKeyValueStore: KeyValueStoring, SettingsStore, @unchecked Sendable {
    /// Seeded on first use: values written before this mirror existed are only in iCloud, and
    /// without a seed they'd be lost the moment the user turns iCloud off.
    public static let shared: CloudKeyValueStore = {
        let store = CloudKeyValueStore()
        store.seedMirror()
        return store
    }()

    /// Namespaced so a mirrored value can't be mistaken for a local setting of the same name —
    /// several keys exist in both stores while their migration off `UserDefaults` runs.
    private static let mirrorPrefix = "iCloudMirror."

    private let cloud: KeyValueStoring
    private let mirror: UserDefaults

    public init(
        cloud: KeyValueStoring = NSUbiquitousKeyValueStore.default,
        mirror: UserDefaults = .appGroup
    ) {
        self.cloud = cloud
        self.mirror = mirror
    }

    // MARK: - Reading

    public func object(forKey key: String) -> Any? {
        cloud.object(forKey: key) ?? mirror.object(forKey: Self.mirrorKey(key))
    }

    public func bool(forKey key: String) -> Bool {
        (object(forKey: key) as? NSNumber)?.boolValue ?? false
    }

    public func longLong(forKey key: String) -> Int64 {
        (object(forKey: key) as? NSNumber)?.int64Value ?? 0
    }

    public func double(forKey key: String) -> Double {
        (object(forKey: key) as? NSNumber)?.doubleValue ?? 0
    }

    public func string(forKey key: String) -> String? {
        object(forKey: key) as? String
    }

    public func data(forKey key: String) -> Data? {
        object(forKey: key) as? Data
    }

    public func array(forKey key: String) -> [Any]? {
        object(forKey: key) as? [Any]
    }

    public func dictionary(forKey key: String) -> [String: Any]? {
        object(forKey: key) as? [String: Any]
    }

    public var dictionaryRepresentation: [String: Any] {
        cloud.dictionaryRepresentation
    }

    // MARK: - Writing

    public func set(_ value: Any?, forKey key: String) {
        cloud.set(value, forKey: key)
        mirror.set(value, forKey: Self.mirrorKey(key))
    }

    public func removeObject(forKey key: String) {
        cloud.removeObject(forKey: key)
        mirror.removeObject(forKey: Self.mirrorKey(key))
    }

    // MARK: - Mirror upkeep

    /// Copies everything iCloud currently holds into the mirror. Additive: an unavailable store
    /// reads as empty, and treating that as "the user cleared everything" would wipe the mirror
    /// in exactly the situation it exists for.
    public func seedMirror() {
        for (key, value) in cloud.dictionaryRepresentation {
            mirror.set(value, forKey: Self.mirrorKey(key))
        }
    }

    /// Pulls the given keys back from iCloud, dropping the ones it no longer has. Only safe for
    /// keys iCloud reported as changed — there a missing value is a real removal, not an
    /// unreachable store.
    public func refreshMirror(forKeys keys: [String]) {
        for key in keys {
            if let value = cloud.object(forKey: key) {
                mirror.set(value, forKey: Self.mirrorKey(key))
            } else {
                mirror.removeObject(forKey: Self.mirrorKey(key))
            }
        }
    }

    private static func mirrorKey(_ key: String) -> String {
        mirrorPrefix + key
    }
}

public extension CloudKeyValueStore {
    /// Premium is an acknowledgement rather than a receipt, so there's nothing to restore it from
    /// once it's gone — all the more reason for it to outlive a turned-off iCloud.
    static var hasPremium: Bool {
        shared.bool(forKey: Const.unwatchedPremiumAcknowledged)
    }
}
