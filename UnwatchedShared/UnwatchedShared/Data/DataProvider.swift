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

    public let container: ModelContainer = {
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

        let config = ModelConfiguration(
            schema: DataProvider.schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: enableIcloudSync ? .private("iCloud.com.pentlandFirth.Unwatched") : .none
        )

        Log.info("getModelContainer: config set")

        do {
            do {
                return try ModelContainer(
                    for: DataProvider.schema,
                    migrationPlan: UnwatchedMigrationPlan.self,
                    configurations: [config]
                )
            } catch {
                Log.error("getModelContainer error: \(error)")
            }

            // workaround for migration (disable sync for initial launch)
            Log.info("getModelContainer: fallback")
            let config = ModelConfiguration(
                schema: DataProvider.schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: DataProvider.schema,
                migrationPlan: UnwatchedMigrationPlan.self,
                configurations: [config]
            )
            Task { @MainActor in
                DataProvider.migrationWorkaround(container.mainContext)
            }
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    private static func migrationWorkaround(_ context: ModelContext) {
        // workaround: migration fails during willMigrate (https://developer.apple.com/forums/thread/775060)
        let dict = UnwatchedMigrationPlan.subPlaceVideosIn
        if !dict.isEmpty {
            UnwatchedMigrationPlan.migrateV1p6toV1p7DidMigrate(context)
        }
        UnwatchedMigrationPlan.migrateV1p9toV1p10DidMigrate()
    }

    public let localCacheContainer: ModelContainer = {
        let schema = Schema([CachedImage.self, Transcript.self, CachedChapters.self])
        let fileName = "imageCache.sqlite"

        #if os(tvOS)
        let storeURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent(fileName)
        #elseif os(macOS)
        let storeURL = URL.applicationSupportDirectory.appending(path: fileName)
        #else
        let storeURL = URL.documentsDirectory.appending(path: fileName)
        #endif

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
        WatchTimeEntry.self
    ]

    static let schema = Schema(DataProvider.dbEntries)

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
