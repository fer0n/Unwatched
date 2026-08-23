//
//  DataController.swift
//  Unwatched
//

import SwiftData
import OSLog

public extension ProcessInfo {
    var isXcodePreview: Bool {
        environment["XCODE_RUNNING_FOR_PREVIEWS"] != nil
    }
}

public final class DataProvider: Sendable {
    public static let shared = DataProvider()

    /// Shared between the main app and `UnwatchedShareExtension` so the extension can read/write
    /// the same SwiftData store without launching the app.
    static let appGroupIdentifier = "group.com.pentlandFirth.Unwatched"

    /// Whether the running target actually has the App Group entitlement — tvOS/other targets
    /// don't, so `groupContainer` below falls back to SwiftData's own default (non-shared)
    /// location there instead of failing to resolve the group.
    private static var hasAppGroupEntitlement: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) != nil
    }

    /// SwiftData has a built-in mechanism for exactly this — persisting to (and migrating an
    /// existing store into) an App Group container — via `ModelConfiguration.groupContainer`.
    /// Per Apple's guidance ("Adopting SwiftData for a Core Data app"): "For an app that has the
    /// application-groups entitlement, it persists the data store to the root directory of the
    /// app group container. For apps that evolve from a version that doesn't have any app group
    /// container to a version that has one, SwiftData copies the existing store to the app group
    /// container" — automatically, with no application code needed. Passing an explicit `url:` to
    /// `ModelConfiguration` (the previous approach here) bypasses this entirely, since it skips
    /// SwiftData's own default-location resolution — which is what triggers the automatic copy.
    private static var groupContainer: ModelConfiguration.GroupContainer {
        hasAppGroupEntitlement ? .identifier(appGroupIdentifier) : .none
    }

    public let container: ModelContainer = {
        LaunchTrace.mark(LaunchTrace.Phase.containerBegin)
        Log.info("getModelContainer")
        var enableIcloudSync = UserDefaults.standard.bool(forKey: Const.enableIcloudSync)
        #if os(tvOS)
        enableIcloudSync = true
        #endif

        #if DEBUG
        if CommandLine.arguments.contains("enable-testing") || ProcessInfo.processInfo.isXcodePreview {
            return DataProvider.previewContainer
        }
        #endif

        SettingsMigration.run()

        let config = ModelConfiguration(
            schema: DataProvider.schema,
            groupContainer: DataProvider.groupContainer,
            cloudKitDatabase: enableIcloudSync ? .private("iCloud.com.pentlandFirth.Unwatched") : .none
        )

        Log.info("getModelContainer: config set")

        do {
            let container: ModelContainer
            do {
                container = try ModelContainer(
                    for: DataProvider.schema,
                    migrationPlan: UnwatchedMigrationPlan.self,
                    configurations: [config]
                )
            } catch {
                Log.error("getModelContainer error: \(error)")

                // workaround for migration (disable sync for initial launch)
                Log.info("getModelContainer: fallback")
                let config = ModelConfiguration(
                    schema: DataProvider.schema,
                    groupContainer: DataProvider.groupContainer,
                    cloudKitDatabase: .none
                )
                container = try ModelContainer(
                    for: DataProvider.schema,
                    migrationPlan: UnwatchedMigrationPlan.self,
                    configurations: [config]
                )
            }
            LaunchTrace.mark(LaunchTrace.Phase.containerEnd)
            Task { @MainActor in
                DataProvider.migrationWorkaround(container.mainContext)
            }
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    /// Applies video placements that `migrateV1p6toV1p7` collected but never got to write back.
    ///
    /// Runs on both container paths, not just the fallback: the stage's `didMigrate` can be
    /// skipped while the container itself opens fine (https://developer.apple.com/forums/thread/775060),
    /// so a successful open is no evidence the stage completed. No-op once the placements are gone.
    private static func migrationWorkaround(_ context: ModelContext) {
        if !UnwatchedMigrationPlan.subPlaceVideosIn.isEmpty {
            UnwatchedMigrationPlan.migrateV1p6toV1p7DidMigrate(context)
        }
    }

    public let localCacheContainer: ModelContainer = {
        let schema = Schema([CachedImage.self, Transcript.self, CachedChapters.self])
        let fileName = "imageCache.sqlite"

        // Shared with `UnwatchedShareExtension` (same reasoning as `groupContainer` above) so
        // images cached by one target are visible to the other, instead of each target
        // maintaining its own separate, never-synced `imageCache.sqlite`. Falls back to the
        // per-target sandbox location on targets without the entitlement (tvOS, previews, …).
        let storeURL: URL
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: DataProvider.appGroupIdentifier
        ) {
            storeURL = groupURL.appendingPathComponent(fileName)
        } else {
            #if os(tvOS)
            storeURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent(fileName)
            #elseif os(macOS)
            storeURL = URL.applicationSupportDirectory.appending(path: fileName)
            #else
            storeURL = URL.documentsDirectory.appending(path: fileName)
            #endif
        }

        let config = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: CachedImageMigrationPlan.self,
                configurations: [config]
            )
        } catch {
            // Purely derived data, so a store that won't open is worth discarding rather than
            // crashing on: a store written by a newer schema can't migrate back, and on tvOS the
            // system may leave a partially purged store behind in Library/Caches.
            Log.error("Could not open CachedImage store, discarding it: \(error)")
            DataProvider.removeStore(at: storeURL)

            do {
                return try ModelContainer(
                    for: schema,
                    migrationPlan: CachedImageMigrationPlan.self,
                    configurations: [config]
                )
            } catch {
                fatalError("Could not create CachedImage ModelContainer: \(error)")
            }
        }
    }()

    private static func removeStore(at url: URL) {
        for sidecar in ["", "-wal", "-shm"] {
            let file = url.deletingLastPathComponent()
                .appendingPathComponent(url.lastPathComponent + sidecar)
            do {
                try FileManager.default.removeItem(at: file)
            } catch CocoaError.fileNoSuchFile {
                continue
            } catch {
                Log.error("Could not remove \(file.lastPathComponent): \(error)")
            }
        }
    }

    init() {}

    public static func newContext() -> ModelContext {
        ModelContext(shared.container)
    }

    /// Owns the one context every background data actor writes through, see `SharedContextActor`.
    public static let writeExecutor = DefaultSerialModelExecutor(modelContext: newContext())

    @MainActor
    public static var mainContext: ModelContext {
        shared.container.mainContext
    }

    public static let dbEntries: [any PersistentModel.Type] = [
        Video.self,
        Subscription.self,
        QueueEntry.self,
        InboxEntry.self,
        Chapter.self,
        WatchTimeEntry.self,
        Tag.self
    ]

    public static let schema = Schema(DataProvider.dbEntries)

    public static let previewContainer: ModelContainer = {
        var sharedModelContainer: ModelContainer = {
            let schema = Schema(DataProvider.dbEntries)
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )

            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create preview ModelContainer: \(error)")
            }
        }()
        return sharedModelContainer
    }()
}
