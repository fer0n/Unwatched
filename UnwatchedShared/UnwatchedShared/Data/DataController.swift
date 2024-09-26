//
//  DataController.swift
//  Unwatched
//

import SwiftData

@MainActor
public class DataController {
    public static let dbEntries: [any PersistentModel.Type] = [
        Video.self,
        Subscription.self,
        QueueEntry.self,
        InboxEntry.self,
        Chapter.self
    ]

    static let schema = Schema(DataController.dbEntries)

    public static func modelConfig(_ isStoredInMemoryOnly: Bool = false) -> ModelConfiguration {
        ModelConfiguration(
            schema: DataController.schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly,
            cloudKitDatabase: .none
        )
    }

    public static var getCachedImageContainer: ModelContainer = {
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

    public static func getModelContainer(enableIcloudSync: Bool? = nil) -> ModelContainer {
        let enableIcloudSync = enableIcloudSync ?? UserDefaults.standard.bool(forKey: Const.enableIcloudSync)

        #if DEBUG
        if CommandLine.arguments.contains("enable-testing") {
            return DataController.previewContainer
        }
        #endif

        let config = ModelConfiguration(
            schema: DataController.schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: enableIcloudSync ? .private("iCloud.com.pentlandFirth.Unwatched") : .none
        )

        do {
            if let container = try? ModelContainer(
                for: DataController.schema,
                migrationPlan: UnwatchedMigrationPlan.self,
                configurations: [config]
            ) {
                container.mainContext.undoManager = UndoManager()
                return container
            }

            // workaround for migration (disable sync for initial launch)
            let config = ModelConfiguration(
                schema: DataController.schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: DataController.schema,
                migrationPlan: UnwatchedMigrationPlan.self,
                configurations: [config]
            )
            container.mainContext.undoManager = UndoManager()
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    public static let previewContainer: ModelContainer = {
        var sharedModelContainer: ModelContainer = {
            let schema = Schema(DataController.dbEntries)
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
