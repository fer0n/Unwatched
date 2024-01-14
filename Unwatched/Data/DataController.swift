//
//  DataController.swift
//  Unwatched
//

import Foundation
import SwiftData

@MainActor
class DataController {
    static let dbEntries: [any PersistentModel.Type] = [
        Video.self,
        Subscription.self,
        QueueEntry.self,
        WatchEntry.self,
        InboxEntry.self,
        Chapter.self
    ]

    static let previewContainer: ModelContainer = {
        var sharedModelContainer: ModelContainer = {
            let schema = Schema(DataController.dbEntries)
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }()

        sharedModelContainer.mainContext.insert(Video.dummy)

        return sharedModelContainer
    }()
}
