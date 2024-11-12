//
//  UserDataService.swift
//  Unwatched
//

import Foundation
import SwiftData
import OSLog
import UnwatchedShared

enum UserDataServiceError: Error {
    case noDataToBackupFound
    case directoryError
}

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
        Logger.log.info("fetched \(fetched.count)")
        backup.videos = fetched
        if fetchVideos != nil {
            _ = fetchMapExportable(Video.self)
            // Bug: otherwise subscription fails (maybe because it doesn't have the videos ready otherwise?)
            // also happens if subscriptions is called before fetching videos
        }

        backup.settings         = getSettings()
        backup.queueEntries     = fetchMapExportable(QueueEntry.self)
        backup.inboxEntries     = fetchMapExportable(InboxEntry.self)
        let subs                = fetchMapExportable(Subscription.self)
        backup.subscriptions = subs.filter({ !$0.isArchived || !$0.videosIds.isEmpty })

        if backup.isEmpty {
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
            let includeWatched = !UserDefaults.standard.bool(forKey: Const.exludeWatchHistoryInBackup)
            Logger.log.info("returning fetch")
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

    // loads user data from .unwatchedbackup files
    static func importBackup(_ data: Data) {
        Logger.log.info("importBackup, userdataservice")
        var videoIdDict = [Int: Video]()
        let context = DataProvider.newContext()
        let decoder = JSONDecoder()

        do {
            let backup = try decoder.decode(UnwatchedBackup.self, from: data)
            restoreSettings(backup.settings)

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

        } catch {
            Logger.log.error("error decoding: \(error)")
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
            Logger.log.error("couldn't export: \(error)")
            throw error
        }
    }

    static func saveToIcloud(_ deviceName: String,
                             manual: Bool = false) -> Task<(), Error> {
        return Task {
            do {
                let filename = getBackupsDirectory()?
                    .appendingPathComponent(self.getFileName(deviceName, manual: manual))
                guard let filename = filename else {
                    throw UserDataServiceError.directoryError
                }
                let data = try self.exportFile()
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

    static func getSettings() -> [String: AnyCodable] {
        var result = [String: AnyCodable]()
        for (key, _) in Const.settingsDefaults {
            if let value = UserDefaults.standard.object(forKey: key) {
                result[key] = AnyCodable(value)
            } else {
                Logger.log.warning("Encoding settings key not set/found: \(key)")
            }
        }
        return result
    }

    static func restoreSettings(_ settings: [String: AnyCodable]?) {
        guard let settings else {
            return
        }
        for (key, value) in settings {
            UserDefaults.standard.setValue(value.value, forKey: key)
        }
        NotificationManager.ensurePermissionsAreGivenForSettings()
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

extension URL {
    var creationDate: Date {
        return (try? resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
    }
}

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let intValue = value as? Int {
            try container.encode(intValue)
        } else if let doubleValue = value as? Double {
            try container.encode(doubleValue)
        } else if let stringValue = value as? String {
            try container.encode(stringValue)
        } else if let boolValue = value as? Bool {
            try container.encode(boolValue)
        } else {
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Unsupported type"
                )
            )
        }
    }
}
