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
                let videoModel = video.createVideo()
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

    static func exportFile(_ container: ModelContainer) -> Data? {
        do {
            return try UserDataService.exportUserData(container: container)
        } catch {
            print("couldn't export: \(error)")
        }
        return nil
    }

    static func saveToIcloud(_ container: ModelContainer) -> Task<(), Never> {
        return Task {
            guard let data = self.exportFile(container) else {
                print("no data when trying to save")
                return
            }
            // store file at icloud documents folder
            guard let filename = getBackupsDirectory()?.appendingPathComponent(self.getFileName()) else {
                print("no filename could be created")
                return
            }
            do {
                try data.write(to: filename)
            } catch {
                print("saveToIcloud: \(error)")
            }
        }
    }

    static func getBackupsDirectory() -> URL? {
        if let containerUrl = FileManager.default.url(
            forUbiquityContainerIdentifier: nil
        )?.appendingPathComponent("Documents/Backups") {
            print("containerUrl", containerUrl)
            if !FileManager.default.fileExists(atPath: containerUrl.path, isDirectory: nil) {
                do {
                    print("create directory")
                    try FileManager.default.createDirectory(
                        at: containerUrl, withIntermediateDirectories: true, attributes: nil
                    )
                } catch {
                    print(error.localizedDescription)
                }
            }
            return containerUrl
        }
        print("returing nil")
        return nil
    }

    static func getFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-hh-mm"
        let dateString = formatter.string(from: Date())
        return "\(dateString).unwatchedbackup"
    }
}

struct UnwatchedBackup: Codable {
    var videos = [SendableVideo]()
    var queueEntries = [SendableQueueEntry]()
    var watchEntries = [SendableWatchEntry]()
    var inboxEntries = [SendableInboxEntry]()
    var subscriptions = [SendableSubscription]()
}
