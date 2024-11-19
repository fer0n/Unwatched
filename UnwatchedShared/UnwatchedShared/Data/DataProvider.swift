//
//  DataController.swift
//  Unwatched
//

import SwiftData
import OSLog

public final class DataProvider: Sendable {
    public static let shared = DataProvider()
    
    public let container: ModelContainer = {
        Logger.log.info("getModelContainer")
        var enableIcloudSync = UserDefaults.standard.bool(forKey: Const.enableIcloudSync)
        #if os(tvOS)
            enableIcloudSync = true
        #endif

        #if DEBUG
        if CommandLine.arguments.contains("enable-testing") {
            return DataProvider.previewContainer
        }
        #endif

        let config = ModelConfiguration(
            schema: DataProvider.schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: enableIcloudSync ? .private("iCloud.com.pentlandFirth.Unwatched") : .none
        )
        
        Logger.log.info("getModelContainer: config set")

        do {
            if let container = try? ModelContainer(
                for: DataProvider.schema,
                migrationPlan: UnwatchedMigrationPlan.self,
                configurations: [config]
            ) {
                Logger.log.info("getModelContainer: setting UndoManager")
                Task { @MainActor in
                    container.mainContext.undoManager = UndoManager()
                }
                return container
            }

            // workaround for migration (disable sync for initial launch)
            Logger.log.info("getModelContainer: fallback")
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
                container.mainContext.undoManager = UndoManager()
            }
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    
    public let imageContainer: ModelContainer = {
        let schema = Schema([CachedImage.self])
        
        #if os(tvOS)
        let storeURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("imageCache.sqlite")
        #else
        let storeURL = URL.documentsDirectory.appending(path: "imageCache.sqlite")
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
    
    public static let dbEntries: [any PersistentModel.Type] = [
        Video.self,
        Subscription.self,
        QueueEntry.self,
        InboxEntry.self,
        Chapter.self
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
                fatalError("Could not create ModelContainer: \(error)")
            }
        }()
        return sharedModelContainer
    }()
}
