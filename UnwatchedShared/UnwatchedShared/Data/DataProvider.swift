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

    /// The one context every background data actor writes through.
    ///
    /// Actors that share an executor also share its context and, because the executor is serial,
    /// can never run at the same time. That's what keeps one actor from deleting a row another
    /// one is holding — reading any property on such a model traps in SwiftData
    /// (`_InvalidFutureBackingData.getValue`).
    ///
    /// Serialisation stops at suspension points: an actor that awaits mid-job hands the executor
    /// to the next one. Anything that mutates has to stay synchronous from fetch to save, with
    /// network work hoisted out.
    public static let writer = DataWriter()

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

public struct DataWriter: Sendable {
    public let container: ModelContainer
    public let executor: DefaultSerialModelExecutor

    init() {
        let container = DataProvider.shared.container
        self.container = container
        self.executor = DefaultSerialModelExecutor(modelContext: ModelContext(container))
    }
}

/// A data actor that writes through the app's shared context instead of one of its own.
///
/// Replaces `@ModelActor`, which generates an initialiser that always creates a fresh context.
/// Conformers still get `modelContext` from `ModelActor`; instances stay cheap, so per-call
/// instances are fine and per-job scratch state on them stays isolated.
public protocol SharedContextActor: ModelActor {
    init(writer: DataWriter)
}

public extension SharedContextActor {
    init() {
        self.init(writer: DataProvider.writer)
    }
}
