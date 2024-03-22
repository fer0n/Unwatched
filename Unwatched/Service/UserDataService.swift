//
//  UserDataService.swift
//  Unwatched
//

import Foundation
import SwiftData

enum UserDataServiceError: Error {
    case noDataToBackupFound
    case directoryError
}

struct UserDataService {

    // saves user data as .unwatchedbackup
    static func exportUserData(container: ModelContainer) throws -> Data {
        var backup = UnwatchedBackup()
        let context = ModelContext(container)

        func fetchMapExportable<T: PersistentModel & Exportable>(
            _ model: T.Type,
            _ fetchDesc: FetchDescriptor<T>? = nil
        ) -> [T.ExportType] {
            let fetch = fetchDesc ?? FetchDescriptor<T>()
            if let items = try? context.fetch(fetch) {
                return items.compactMap { $0.toExport }
            }
            return []
        }

        let fetchVideos = getVideoFetchIfMinimal()
        let fetched = fetchMapExportable(Video.self, fetchVideos)
        print("fetched \(fetched.count)")
        backup.videos = fetched
        if fetchVideos != nil {
            _ = fetchMapExportable(Video.self)
            // Bug: otherwise subscription fails (maybe because it doesn't have the videos ready otherwise?)
            // also happens if subscriptions is called before fetching videos
        }
        backup.subscriptions    = fetchMapExportable(Subscription.self)
        backup.queueEntries     = fetchMapExportable(QueueEntry.self)
        backup.watchEntries     = fetchMapExportable(WatchEntry.self)
        backup.inboxEntries     = fetchMapExportable(InboxEntry.self)

        if checkIfBackupEmpty(backup) {
            print("checkIfBackupEmpty")
            throw UserDataServiceError.noDataToBackupFound
        }

        let encoder = JSONEncoder()
        return try encoder.encode(backup)
    }

    static func getVideoFetchIfMinimal() -> FetchDescriptor<Video>? {
        let minimalBackups = UserDefaults.standard.object(forKey: Const.minimalBackups) as? Bool ?? true
        if minimalBackups {
            guard let lastWeek = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) else {
                return nil
            }
            print("returning fetch")
            return FetchDescriptor<Video>(predicate: #Predicate {
                $0.bookmarkedDate != nil
                    || $0.watched == true
                    || $0.queueEntry != nil
                    || $0.inboxEntry != nil
                    || ($0.publishedDate ?? lastWeek) > lastWeek
            })
        }
        return nil
    }

    static func checkIfBackupEmpty(_ backup: UnwatchedBackup) -> Bool {
        return backup.videos.isEmpty
            && backup.queueEntries.isEmpty
            && backup.watchEntries.isEmpty
            && backup.inboxEntries.isEmpty
            && backup.subscriptions.isEmpty
    }

    // loads user data from .unwatchedbackup files
    static func importBackup(_ data: Data, container: ModelContainer) {
        print("importBackup, userdataservice")
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
                    if let video = videoIdDict[entry.videoId] {
                        var modelEntry = entry.toModel
                        context.insert(modelEntry)
                        modelEntry.video = video
                    }
                }
            }

            insertModelsFor(backup.queueEntries)
            insertModelsFor(backup.watchEntries)
            insertModelsFor(backup.inboxEntries)

            // Subscriptions
            for subscription in backup.subscriptions {
                let subscriptionModel = subscription.toModel
                context.insert(subscriptionModel)

                subscriptionModel.onlyTriageAfter = subscriptionModel.mostRecentVideoDate
                subscriptionModel.mostRecentVideoDate = nil
                let videos = subscription.videosIds.compactMap { videoIdDict[$0] }
                subscriptionModel.videos = videos
            }

            try context.save()

        } catch {
            print("error decoding: \(error)")
        }
    }

    static func exportFile(_ container: ModelContainer) throws -> Data {
        do {
            return try UserDataService.exportUserData(container: container)
        } catch {
            print("couldn't export: \(error)")
            throw error
        }
    }

    static func saveToIcloud(_ deviceName: String, _ container: ModelContainer) -> Task<(), Error> {

        return Task {
            do {
                let filename = getBackupsDirectory()?.appendingPathComponent(self.getFileName(deviceName))
                guard let filename = filename else {
                    throw UserDataServiceError.directoryError
                }
                let data = try self.exportFile(container)
                try data.write(to: filename)
            } catch {
                print("saveToIcloud: \(error)")
                throw error
            }
        }
    }

    static func getBackupsDirectory() -> URL? {
        if let containerUrl = FileManager.default.url(
            forUbiquityContainerIdentifier: nil
        )?.appendingPathComponent("Documents/Backups") {
            print("containerUrl \(containerUrl)")
            if !FileManager.default.fileExists(atPath: containerUrl.path, isDirectory: nil) {
                do {
                    print("create directory")
                    try FileManager.default.createDirectory(
                        at: containerUrl, withIntermediateDirectories: true, attributes: nil
                    )
                } catch {
                    print("\(error.localizedDescription)")
                }
            }
            return containerUrl
        }
        print("backupsDirectory: nil")
        return nil
    }

    static func getFileName(_ deviceName: String) -> String {
        let dateFormatter = ISO8601DateFormatter()
        let dateString = dateFormatter.string(from: Date())
        return "\(deviceName)_\(dateString).unwatchedbackup"
    }
}

struct UnwatchedBackup: Codable {
    var videos = [SendableVideo]()
    var queueEntries = [SendableQueueEntry]()
    var watchEntries = [SendableWatchEntry]()
    var inboxEntries = [SendableInboxEntry]()
    var subscriptions = [SendableSubscription]()
}
