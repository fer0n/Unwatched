//
//  UserDataService.swift
//  Unwatched
//

import Foundation
import SwiftData
import OSLog

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
        Logger.log.info("fetched \(fetched.count)")
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
            Logger.log.info("checkIfBackupEmpty")
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
            Logger.log.info("returning fetch")
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
        Logger.log.info("importBackup, userdataservice")
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
                let videos = subscription.videosIds.compactMap { videoIdDict[$0] }
                subscriptionModel.videos = videos
            }

            try context.save()

        } catch {
            Logger.log.error("error decoding: \(error)")
        }
    }

    static func exportFile(_ container: ModelContainer) throws -> Data {
        do {
            return try UserDataService.exportUserData(container: container)
        } catch {
            Logger.log.error("couldn't export: \(error)")
            throw error
        }
    }

    static func saveToIcloud(_ deviceName: String,
                             _ container: ModelContainer,
                             manual: Bool = false) -> Task<(), Error> {
        return Task {
            do {
                let filename = getBackupsDirectory()?
                    .appendingPathComponent(self.getFileName(deviceName, manual: manual))
                guard let filename = filename else {
                    throw UserDataServiceError.directoryError
                }
                let data = try self.exportFile(container)
                try data.write(to: filename)
            } catch {
                Logger.log.error("saveToIcloud: \(error)")
                throw error
            }
        }
    }

    static func autoDeleteBackups() -> Int {
        let files = getFilesToDelete()
        for file in files {
            deleteFile(file)
        }
        return files.count
    }

    static func getFilesToDelete() -> [URL] {
        guard let directory = getBackupsDirectory() else {
            return []
        }
        do {
            let fileNames = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            let files = fileNames.map { directory.appendingPathComponent($0) }

            let toDelete = filterOutKeeperFiles(files)
            Logger.log.info("deleting: \(toDelete.count) files")
            return toDelete
        } catch {
            Logger.log.error("getFilesToDelete: \(error)")
            return []
        }
    }

    static func filterOutKeeperFiles(_ files: [URL]) -> [URL] {
        let calendar = Calendar.current
        let oneWeekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: Date())!
        let halfYearAgo = calendar.date(byAdding: .month, value: -6, to: Date())!

        var manualFiles = [URL]()
        var lastWeekFiles = [URL]()
        var weeklyFiles = [URL]()
        var monthlyFiles = [URL]()

        for file in files {
            if file.lastPathComponent.contains("_m") {
                manualFiles.append(file)
                continue
            }

            let attributes = try? FileManager.default.attributesOfItem(atPath: file.path)
            let creationDate = attributes?[.creationDate] as? Date ?? Date()

            if creationDate >= oneWeekAgo {
                lastWeekFiles.append(file)
            } else if creationDate >= halfYearAgo {
                let weekOfYear = calendar.component(.weekOfYear, from: creationDate)
                if weeklyFiles.first(where: {
                    calendar.component(.weekOfYear, from: $0.creationDate) == weekOfYear
                }) == nil {
                    weeklyFiles.append(file)
                }
            } else {
                let month = calendar.component(.month, from: creationDate)
                if monthlyFiles.first(where: { calendar.component(.month, from: $0.creationDate) == month }) == nil {
                    monthlyFiles.append(file)
                }
            }
        }
        let keepers = manualFiles + lastWeekFiles + weeklyFiles + monthlyFiles
        return files.filter { !keepers.contains($0) }
    }

    static func deleteFile(_ filepath: URL) {
        do {
            try FileManager.default.removeItem(at: filepath)
        } catch {
            Logger.log.error("deleteFile: \(error)")
        }
    }

    static func getBackupsDirectory() -> URL? {
        if let containerUrl = FileManager.default.url(
            forUbiquityContainerIdentifier: nil
        )?.appendingPathComponent("Documents/Backups") {
            Logger.log.info("containerUrl \(containerUrl)")
            if !FileManager.default.fileExists(atPath: containerUrl.path, isDirectory: nil) {
                do {
                    Logger.log.info("create directory")
                    try FileManager.default.createDirectory(
                        at: containerUrl, withIntermediateDirectories: true, attributes: nil
                    )
                } catch {
                    Logger.log.error("\(error.localizedDescription)")
                }
            }
            return containerUrl
        }
        Logger.log.info("backupsDirectory: nil")
        return nil
    }

    static func getFileName(_ deviceName: String, manual: Bool = false) -> String {
        let dateString = Date().formatted(.iso8601)
        return "\(deviceName)_\(dateString)\(manual ? "_m" : "").unwatchedbackup"
    }
}

struct UnwatchedBackup: Codable {
    var videos = [SendableVideo]()
    var queueEntries = [SendableQueueEntry]()
    var watchEntries = [SendableWatchEntry]()
    var inboxEntries = [SendableInboxEntry]()
    var subscriptions = [SendableSubscription]()
}

extension URL {
    var creationDate: Date {
        return (try? resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
    }
}
