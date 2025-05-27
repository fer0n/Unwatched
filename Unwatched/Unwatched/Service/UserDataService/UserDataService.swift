//
//  UserDataService.swift
//  Unwatched
//

import Foundation
import SwiftData
import SwiftUI
import OSLog
import UnwatchedShared

struct UserDataService {

    // saves user data as .unwatchedbackup
    static func exportUserData() throws -> Data {
        var backup = UnwatchedBackup()
        let context = DataProvider.newContext()

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
        Log.info("fetched \(fetched.count)")
        backup.videos = fetched
        if fetchVideos != nil {
            _ = fetchMapExportable(Video.self)
            // Bug: otherwise subscription fails (maybe because it doesn't have the videos ready otherwise?)
            // also happens if subscriptions is called before fetching videos
        }

        backup.settings         = getSettings()
        backup.queueEntries     = fetchMapExportable(QueueEntry.self)
        backup.inboxEntries     = fetchMapExportable(InboxEntry.self)
        var subs                = fetchMapExportable(Subscription.self)
        subs = subs.map { var sub = $0; sub.persistentId = nil; return sub }
        backup.subscriptions = subs.filter({ !$0.isArchived || !$0.videosIds.isEmpty })

        if backup.isEmpty {
            Log.info("checkIfBackupEmpty")
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
            let includeWatched = !UserDefaults.standard.bool(forKey: Const.exludeWatchHistoryInBackup)
            Log.info("returning fetch")
            return FetchDescriptor<Video>(predicate: #Predicate {
                $0.bookmarkedDate != nil
                    || (includeWatched && $0.watchedDate != nil)
                    || $0.queueEntry != nil
                    || $0.inboxEntry != nil
                    || ($0.publishedDate ?? lastWeek) > lastWeek
            })
        }
        return nil
    }

    static func restoreVideoData(from backup: UnwatchedBackup) throws {
        var videoIdDict = [Int: Video]()
        let context = DataProvider.newContext()

        // Videos, get id mapping
        for video in backup.videos {
            let videoModel = video.createVideo(extractChapters: ChapterService.extractChapters)
            context.insert(videoModel)
            if let id = video.videoId {
                videoIdDict[id] = videoModel
            }
        }

        // Use the extracted functions
        insertModelsFor(backup.queueEntries, videoIdDict: videoIdDict, context: context)
        insertModelsFor(backup.inboxEntries, videoIdDict: videoIdDict, context: context)
        migrateWatchEntries(backup.watchEntries, videoIdDict: &videoIdDict)

        // Subscriptions
        for subscription in backup.subscriptions {
            let subscriptionModel = subscription.toModel
            context.insert(subscriptionModel)
            let videos = subscription.videosIds.compactMap { videoIdDict[$0] }
            subscriptionModel.videos = videos
        }

        try context.save()
    }

    // loads user data from .unwatchedbackup files
    static func importBackup(_ data: Data, settingsOnly: Bool = false) {
        Log.info("importBackup, userdataservice")
        let decoder = JSONDecoder()

        do {
            let backup = try decoder.decode(UnwatchedBackup.self, from: data)
            restoreSettings(backup.settings)
            if !settingsOnly {
                try restoreVideoData(from: backup)
            }
        } catch {
            Log.error("error decoding: \(error)")
        }
    }

    static private func insertModelsFor<T: ModelConvertable>(
        _ entries: [T],
        videoIdDict: [Int: Video],
        context: ModelContext
    ) {
        for entry in entries {
            if let video = videoIdDict[entry.videoId] {
                var modelEntry = entry.toModel
                context.insert(modelEntry)
                modelEntry.video = video
            }
        }
    }

    static private func migrateWatchEntries(
        _ entries: [SendableWatchEntry],
        videoIdDict: inout [Int: Video]
    ) {
        let videoEntries = Dictionary(grouping: entries, by: { $0.videoId })
        for (_, entries) in videoEntries {
            let entries = entries.sorted(by: {
                $0.date ?? .distantPast > $1.date ?? .distantPast
            })
            guard let first = entries.first,
                  let lastEntryDate = first.date,
                  let video = videoIdDict[first.videoId] else {
                continue
            }

            video.watchedDate = lastEntryDate
            videoIdDict[first.videoId] = video
        }
    }

    static func exportFile() throws -> Data {
        do {
            return try UserDataService.exportUserData()
        } catch {
            Log.error("couldn't export: \(error)")
            throw error
        }
    }

    @MainActor
    static func getBackupFileName(manual: Bool = false) -> String {
        let deviceName = Device.deviceName
        return self.getFileName(deviceName, manual: manual)
    }

    static func saveToIcloud(manual: Bool = false) -> Task<(), Error> {
        return Task {
            let filename = await MainActor.run {
                self.getBackupFileName(manual: manual)
            }
            do {
                guard let directory = getBackupsDirectory()?.appendingPathComponent(filename) else {
                    throw UserDataServiceError.directoryError
                }
                let data = try self.exportFile()
                try data.write(to: directory)
            } catch {
                Log.error("saveToIcloud: \(error)")
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
            Log.info("deleting: \(toDelete.count) files")
            return toDelete
        } catch {
            Log.error("getFilesToDelete: \(error)")
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
            Log.error("deleteFile: \(error)")
        }
    }

    static func getBackupsDirectory() -> URL? {
        if let containerUrl = FileManager.default.url(
            forUbiquityContainerIdentifier: nil
        )?.appendingPathComponent("Documents/Backups") {
            Log.info("containerUrl \(containerUrl)")
            if !FileManager.default.fileExists(atPath: containerUrl.path, isDirectory: nil) {
                do {
                    Log.info("create directory")
                    try FileManager.default.createDirectory(
                        at: containerUrl, withIntermediateDirectories: true, attributes: nil
                    )
                } catch {
                    Log.error("\(error.localizedDescription)")
                }
            }
            return containerUrl
        }
        Log.info("backupsDirectory: nil")
        return nil
    }

    static func getFileName(_ deviceName: String, manual: Bool = false) -> String {
        let dateString = Date().formatted(.iso8601)
        return "\(deviceName)_\(dateString)\(manual ? "_m" : "").unwatchedbackup"
    }
}

struct UnwatchedBackup: Codable {
    var settings: [String: AnyCodable]? = [:]
    var subscriptions   = [SendableSubscription]()
    var videos          = [SendableVideo]()
    var queueEntries    = [SendableQueueEntry]()
    var inboxEntries    = [SendableInboxEntry]()
    var watchEntries    = [SendableWatchEntry]() // Legacy

    var isEmpty: Bool {
        videos.isEmpty
            && queueEntries.isEmpty
            && watchEntries.isEmpty
            && inboxEntries.isEmpty
            && subscriptions.isEmpty
            && (settings?.isEmpty ?? true)
    }
}
