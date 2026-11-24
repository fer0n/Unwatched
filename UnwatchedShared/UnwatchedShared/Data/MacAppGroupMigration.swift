//
//  MacAppGroupMigration.swift
//  UnwatchedShared
//

#if os(macOS)
import Foundation
import SwiftData

// Workaround: installs that skipped 2.1 can't reach their store in the app group anymore.
// Remove once 2.1 is no longer a likely update path.
public enum MacAppGroupMigration {
    static let doneKey = "macStoreMovedOutOfAppGroup"
    static let outcomeKey = "macStoreMigrationOutcome"

    public enum Outcome: String {
        case fresh, skipped, skippedSynced
    }

    static func detectSkippedMigration(defaults: UserDefaults = .standard) {
        if defaults.bool(forKey: doneKey) {
            return
        }
        let outcome = outcome(defaults: defaults)
        if outcome != .fresh {
            setAsideStore(ModelConfiguration(groupContainer: .none, cloudKitDatabase: .none).url)
            defaults.set(true, forKey: Const.backupOnlyWithContent)
            defaults.removeObject(forKey: Const.syncTotalsCaughtUp)
        }
        if outcome == .skipped {
            defaults.set(false, forKey: Const.onboardingCompleted)
            defaults.set(false, forKey: Const.onboardingStarted)
            defaults.set(false, forKey: Const.welcomeBackHandled)
        }
        Log.data.info("Store migration: \(outcome.rawValue)")
        defaults.set(outcome.rawValue, forKey: outcomeKey)
        defaults.set(true, forKey: doneKey)
    }

    static func outcome(defaults: UserDefaults) -> Outcome {
        guard defaults.bool(forKey: Const.onboardingCompleted) else {
            return .fresh
        }
        return defaults.bool(forKey: Const.enableIcloudSync) ? .skippedSynced : .skipped
    }

    static func takeOutcome(defaults: UserDefaults = .standard) -> Outcome? {
        let outcome = defaults.string(forKey: outcomeKey).flatMap(Outcome.init)
        defaults.removeObject(forKey: outcomeKey)
        return outcome
    }

    static func setAsideStore(_ store: URL) {
        let fileManager = FileManager.default
        let directory = store.deletingLastPathComponent()
        let supportDirectory = ".\(store.deletingPathExtension().lastPathComponent)_SUPPORT"
        let names = ((try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? [])
            .filter { $0.hasPrefix(store.lastPathComponent) || $0 == supportDirectory }
        for name in names {
            let target = directory.appending(path: "preAppGroup-\(name)")
            do {
                try? fileManager.removeItem(at: target)
                try fileManager.moveItem(at: directory.appending(path: name), to: target)
            } catch {
                Log.data.error("Setting aside \(name) failed: \(error)")
            }
        }
    }
}
#endif
