//
//  DataController.swift
//  Unwatched
//

import SwiftData
import OSLog
#if os(macOS)
import Security
#endif

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

        #if os(macOS)
        if enableIcloudSync && !DataProvider.hasCloudKitContainerEntitlement {
            Log.warning("Disabling iCloud sync: the app does not have the required CloudKit entitlement")
            enableIcloudSync = false
            UserDefaults.standard.set(false, forKey: Const.enableIcloudSync)
        }
        #endif

        #if DEBUG
        if CommandLine.arguments.contains("enable-testing") || ProcessInfo.processInfo.isXcodePreview {
            return DataProvider.previewContainer
        }
        #endif

        #if os(macOS)
        let storeURLs: [URL]
        do {
            storeURLs = try DataProvider.storeURLs()
        } catch {
            fatalError("Could not prepare ModelContainer directory: \(error)")
        }
        #else
        let storeURLs: [URL?] = [nil]
        #endif

        var lastError: Error?
        for storeURL in storeURLs {
            #if os(macOS)
            Log.info("getModelContainer: trying store \(storeURL)")
            let config = ModelConfiguration(
                schema: DataProvider.schema,
                url: storeURL,
                cloudKitDatabase: enableIcloudSync ? .private("iCloud.com.pentlandFirth.Unwatched") : .none
            )
            #else
            let config = ModelConfiguration(
                schema: DataProvider.schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: enableIcloudSync ? .private("iCloud.com.pentlandFirth.Unwatched") : .none
            )
            #endif

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
            #if os(macOS)
            let fallbackConfig = ModelConfiguration(
                schema: DataProvider.schema,
                url: storeURL,
                cloudKitDatabase: .none
            )
            #else
            let fallbackConfig = ModelConfiguration(
                schema: DataProvider.schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            #endif

            do {
                let container = try ModelContainer(
                    for: DataProvider.schema,
                    migrationPlan: UnwatchedMigrationPlan.self,
                    configurations: [fallbackConfig]
                )
                Task { @MainActor in
                    DataProvider.migrationWorkaround(container.mainContext)
                }
                return container
            } catch {
                Log.error("getModelContainer fallback error: \(error)")
                lastError = error
            }
        }

        fatalError("Could not create ModelContainer: \(String(describing: lastError))")
    }()

    #if os(macOS)
    private static let hasCloudKitContainerEntitlement: Bool = {
        guard let task = SecTaskCreateFromSelf(nil),
              let containerIdentifiers = SecTaskCopyValueForEntitlement(
                task,
                "com.apple.developer.icloud-container-identifiers" as CFString,
                nil
              ) as? [String] else {
            return false
        }
        return containerIdentifiers.contains("iCloud.com.pentlandFirth.Unwatched")
    }()

    /// Older builds used SwiftData's generic `default.store` directly in Application Support.
    /// Try it for existing installs, then fall back to an app-specific store when it belongs
    /// to another SwiftData app or has an unsupported schema.
    private static func storeURLs(fileManager: FileManager = .default) throws -> [URL] {
        let applicationSupportURL = URL.applicationSupportDirectory
        let appDirectoryURL = applicationSupportURL.appending(
            path: Const.bundleId,
            directoryHint: .isDirectory
        )
        try fileManager.createDirectory(
            at: appDirectoryURL,
            withIntermediateDirectories: true
        )

        let appStoreURL = appDirectoryURL.appending(path: "default.store")
        let legacyStoreURL = applicationSupportURL.appending(path: "default.store")
        let appStoreExists = fileManager.fileExists(atPath: appStoreURL.path)
        let legacyStoreExists = fileManager.fileExists(atPath: legacyStoreURL.path)

        if !appStoreExists && legacyStoreExists {
            return [legacyStoreURL, appStoreURL]
        }
        return [appStoreURL]
    }
    #endif

    private static func migrationWorkaround(_ context: ModelContext) {
        // workaround: migration fails during willMigrate (https://developer.apple.com/forums/thread/775060)
        let dict = UnwatchedMigrationPlan.subPlaceVideosIn
        if !dict.isEmpty {
            UnwatchedMigrationPlan.migrateV1p6toV1p7DidMigrate(context)
        }
        UnwatchedMigrationPlan.migrateV1p9toV1p10DidMigrate()
    }

    public let localCacheContainer: ModelContainer = {
        let schema = Schema([CachedImage.self, Transcript.self])
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
            fatalError("Could not create CachedImage ModelContainer: \(error)")
        }
    }()

    init() {}

    public static func newContext() -> ModelContext {
        ModelContext(shared.container)
    }

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
