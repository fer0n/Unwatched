//
//  MacAppGroupMigration.swift
//  UnwatchedShared
//

#if os(macOS)
import Foundation
import SwiftData

// Workaround: App Store Connect won't transfer a sandboxed Mac app that claims a group container.
// Remove once the macOS build no longer has the app group entitlement.
public enum MacAppGroupMigration {
    static let doneKey = "macStoreMovedOutOfAppGroup"
    static let outcomeKey = "macStoreMigrationOutcome"

    public enum Outcome: String {
        case moved, noStore, appStoreNewer, failed
    }

    static func moveStoreOutOfGroup(defaults: UserDefaults = .standard) -> Bool {
        if defaults.bool(forKey: doneKey) {
            return true
        }
        let groupStore = ModelConfiguration(
            groupContainer: .identifier(DataProvider.appGroupIdentifier),
            cloudKitDatabase: .none
        ).url
        let appStore = ModelConfiguration(groupContainer: .none, cloudKitDatabase: .none).url
        let outcome: Outcome
        do {
            outcome = try copyStore(from: groupStore, to: appStore)
        } catch {
            Log.data.error("Moving the store out of the app group failed: \(error)")
            defaults.set(Outcome.failed.rawValue, forKey: outcomeKey)
            return false
        }
        Log.data.info("Moving the store out of the app group: \(outcome.rawValue)")
        defaults.set(outcome.rawValue, forKey: outcomeKey)
        defaults.set(true, forKey: doneKey)
        return true
    }

    static func takeOutcome(defaults: UserDefaults = .standard) -> Outcome? {
        let outcome = defaults.string(forKey: outcomeKey).flatMap(Outcome.init)
        defaults.removeObject(forKey: outcomeKey)
        return outcome
    }

    static func copyStore(from source: URL, to destination: URL) throws -> Outcome {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: source.path) else {
            return .noStore
        }
        if let appStoreDate = lastModified(destination), let groupStoreDate = lastModified(source),
           appStoreDate > groupStoreDate {
            return .appStoreNewer
        }
        let sourceDirectory = source.deletingLastPathComponent()
        let destinationDirectory = destination.deletingLastPathComponent()
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        for name in try storeFiles(of: destination) {
            try fileManager.removeItem(at: destinationDirectory.appending(path: name))
        }
        do {
            for name in try storeFiles(of: source) {
                try fileManager.copyItem(
                    at: sourceDirectory.appending(path: name),
                    to: destinationDirectory.appending(path: name)
                )
            }
        } catch {
            for name in (try? storeFiles(of: destination)) ?? [] {
                try? fileManager.removeItem(at: destinationDirectory.appending(path: name))
            }
            throw error
        }
        return .moved
    }

    private static func lastModified(_ store: URL) -> Date? {
        [store, URL(fileURLWithPath: store.path + "-wal")]
            .compactMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }
            .max()
    }

    private static func storeFiles(of store: URL) throws -> [String] {
        let supportDirectory = ".\(store.deletingPathExtension().lastPathComponent)_SUPPORT"
        return try FileManager.default.contentsOfDirectory(atPath: store.deletingLastPathComponent().path)
            .filter { $0.hasPrefix(store.lastPathComponent) || $0 == supportDirectory }
    }
}
#endif
