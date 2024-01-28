//
//  UserDataService.swift
//  Unwatched
//

import Foundation
import SwiftData

struct UserDataService {

    // saves user data as .unwatchedbackup
    static func exportUserData(container: ModelContainer) throws -> Data {
        var backup = UnwatchedBackup()
        let context = ModelContext(container)

        func fetchMapExportable<T: PersistentModel & Exportable>(_ model: T.Type) -> [T.ExportType] {
            let fetch = FetchDescriptor<T>()
            if let items = try? context.fetch(fetch) {
                return items.compactMap { $0.toExport }
            }
            return []
        }

        backup.videos           = fetchMapExportable(Video.self)
        backup.queueEntries     = fetchMapExportable(QueueEntry.self)
        backup.watchEntries     = fetchMapExportable(WatchEntry.self)
        backup.inboxEntries     = fetchMapExportable(InboxEntry.self)
        backup.subscriptions    = fetchMapExportable(Subscription.self)

        let encoder = JSONEncoder()
        return try encoder.encode(backup)
    }

    // loads user data from .unwatchedbackup files
    static func importBackup(_ data: Data, container: ModelContainer) {
        var videoIdDict = [Int: Video]()

        let context = ModelContext(container)
        let decoder = JSONDecoder()
        do {
            let backup = try decoder.decode(UnwatchedBackup.self, from: data)

            // Videos, get id mapping
            for video in backup.videos {
                let videoModel = video.getVideo()
                context.insert(videoModel)
                if let id = video.persistendId {
                    videoIdDict[id] = videoModel
                }
            }

            func insertModelsFor<T: ModelConvertable>(_ entries: [T]) {
                for entry in entries {
                    var modelEntry = entry.toModel
                    context.insert(modelEntry)
                    modelEntry.video = videoIdDict[entry.videoId]
                }
            }

            insertModelsFor(backup.queueEntries)
            insertModelsFor(backup.watchEntries)
            insertModelsFor(backup.inboxEntries)

            // Subscriptions
            for subscription in backup.subscriptions {
                let subscriptionModel = subscription.toModel
                context.insert(subscriptionModel)
                subscriptionModel.videos = subscription.videosIds.compactMap { videoIdDict[$0] }
            }

            try context.save()

        } catch {
            print("error decoding: \(error)")
        }
    }
}

// TODO: - import and see if videos show up
// TODO: - try maybe queue entries and try to link them together again

struct UnwatchedBackup: Codable {
    var videos = [SendableVideo]()
    var queueEntries = [SendableQueueEntry]()
    var watchEntries = [SendableWatchEntry]()
    var inboxEntries = [SendableInboxEntry]()
    var subscriptions = [SendableSubscription]()
}
