//
//  CloudKeyValueStore+PlaybackSpeed.swift
//  UnwatchedShared
//

import Combine
import Foundation

public extension CloudKeyValueStore {
    static var defaultPlaybackSpeed: Double {
        get {
            let synced = shared.double(forKey: Const.playbackSpeed)
            // pre-sync value, until `SettingsMigration` moves it
            let speed = synced > 0 ? synced : UserDefaults.standard.double(forKey: Const.playbackSpeed)
            return speed > 0 ? speed : 1
        }
        set {
            shared.set(newValue, forKey: Const.playbackSpeed)
            // otherwise the write can sit in memory until the app is suspended or killed, and never upload
            NSUbiquitousKeyValueStore.default.synchronize()
        }
    }

    /// Speeds set on other devices, delivered on the main queue.
    static var defaultPlaybackSpeedChanges: AnyPublisher<Double, Never> {
        NotificationCenter.default
            .publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)
            .filter { notification in
                let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
                return keys?.contains(Const.playbackSpeed) == true
            }
            .map { _ in defaultPlaybackSpeed }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}
