//
//  SyncHandoff.swift
//  UnwatchedShared
//

import Foundation

public struct SyncRequest: Sendable, Equatable {
    public let fromKind: SyncDeviceKind
    public let date: Date
}

@MainActor
public enum SyncHandoff {
    private static let syncOnPrefix = "syncOn."
    nonisolated private static let requestKey = "syncRequest"
    private static let handledRequestDateKey = "handledSyncRequestDate"
    private static let requestLifetime: TimeInterval = 14 * 24 * 60 * 60

    private static var store: NSUbiquitousKeyValueStore { .default }
    private static var ownSyncOnKey: String { syncOnPrefix + DeviceIdentity.id }

    public static func publishSyncState(_ isOn: Bool) {
        let isPublished = store.object(forKey: ownSyncOnKey) != nil
        if isOn, !isPublished {
            store.set(true, forKey: ownSyncOnKey)
        } else if !isOn, isPublished {
            store.removeObject(forKey: ownSyncOnKey)
        }
    }

    public static var isSyncOnElsewhere: Bool {
        store.dictionaryRepresentation.keys.contains { $0.hasPrefix(syncOnPrefix) && $0 != ownSyncOnKey }
    }

    public static func requestSync(on deviceId: String) {
        store.set([
            "kind": SyncDeviceKind.current.rawValue,
            "date": Date(),
            "target": deviceId
        ], forKey: requestKey)
        store.synchronize()
    }

    public static func pendingRequest() -> SyncRequest? {
        guard let dict = store.dictionary(forKey: requestKey),
              let date = dict["date"] as? Date,
              dict["target"] as? String == DeviceIdentity.id,
              date.timeIntervalSinceNow > -requestLifetime else {
            return nil
        }
        if let handled = UserDefaults.standard.object(forKey: handledRequestDateKey) as? Date, handled >= date {
            return nil
        }
        return SyncRequest(fromKind: SyncDeviceKind(stored: dict["kind"]), date: date)
    }

    public static func markHandled(_ request: SyncRequest) {
        UserDefaults.standard.set(request.date, forKey: handledRequestDateKey)
    }

    public static func declinePendingRequest() {
        pendingRequest().map(markHandled)
    }

    public static var requestChanges: AsyncFilterSequence<NotificationCenter.Notifications> {
        NotificationCenter.default
            .notifications(named: NSUbiquitousKeyValueStore.didChangeExternallyNotification)
            .filter { notification in
                let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
                return keys.contains(requestKey)
            }
    }

    public static func refresh() {
        store.synchronize()
    }
}
