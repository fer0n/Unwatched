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

        if Const.includeStatsInBackup.bool ?? true {
            let stats = fetchMapExportable(WatchTimeEntry.self)
            let grouped = Dictionary(grouping: stats, by: { $0.channelId })
            backup.channelStatistics = grouped.map { (key, value) in
                SendableChannelStatistics(
                    channelId: key,
                    entries: value.map { SendableChannelStatistics.Entry(date: $0.date, time: $0.watchTime) }
                )
            }
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
        let json = try encoder.encode(backup)
        return compress(json)
    }

    // backups are zlib-compressed JSON; older backups (and test fixtures) are still plain JSON
    private static let compressionMagic = Data([0x55, 0x57, 0x5a, 0x31]) // "UWZ1"

    private static func compress(_ data: Data) -> Data {
        guard let compressed = try? (data as NSData).compressed(using: .zlib) as Data else {
            return data
        }
        return compressionMagic + compressed
    }

    private static func decompress(_ data: Data) -> Data {
        guard data.starts(with: compressionMagic) else {
            return data
        }
        let payload = data.dropFirst(compressionMagic.count)
        guard let decompressed = try? (payload as NSData).decompressed(using: .zlib) as Data else {
            return data
        }
        return decompressed
    }

    static func getVideoFetchIfMinimal() -> FetchDescriptor<Video>? {
        let includeUnimportantVideos = UserDefaults.standard.object(
            forKey: Const.includeUnimportantVideosInBackup
        ) as? Bool ?? false
        if !includeUnimportantVideos {
            guard let lastWeek = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) else {
                return nil
            }
            let includeWatched = UserDefaults.standard.object(
                forKey: Const.includeWatchHistoryInBackup
            ) as? Bool ?? true
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
            let videoModel = video.createVideo()
            context.insert(videoModel)
            if let id = video.videoId {
                videoIdDict[id] = videoModel
            }
        }

        // Use the extracted functions
        insertModelsFor(backup.queueEntries, videoIdDict: videoIdDict, context: context)
        insertModelsFor(backup.inboxEntries, videoIdDict: videoIdDict, context: context)
        migrateWatchEntries(backup.watchEntries, videoIdDict: &videoIdDict)

        // Statistics
        for channelStat in backup.channelStatistics ?? [] {
            for entry in channelStat.entries {
                let model = WatchTimeEntry(
                    date: entry.date,
                    channelId: channelStat.channelId,
                    watchTime: entry.time
                )
                context.insert(model)
            }
        }

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
            let backup = try decoder.decode(UnwatchedBackup.self, from: decompress(data))
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

    // both callers run on @MainActor; hop off it since this reads/writes full
    // iCloud file contents, which can block on a synchronous download per file
    static func autoDeleteBackups(recompressLimit: Int? = nil) async -> (deleted: Int, recompressed: Int) {
        await Task.detached(priority: .utility) {
            let files = getFilesToDelete()
            for file in files {
                deleteFile(file)
            }
            let recompressed = recompressExistingBackups(limit: recompressLimit)
            return (files.count, recompressed)
        }.value
    }

    // older backups predate compression; bring them in line with newly written ones.
    // `limit` stops after that many recompressions (oldest-first) instead of touching
    // every file, so an automatic run doesn't trigger a large burst of iCloud downloads.
    @discardableResult
    static func recompressExistingBackups(limit: Int? = nil) -> Int {
        guard let directory = getBackupsDirectory(createIfMissing: false),
              let fileNames = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else {
            return 0
        }
        let files = fileNames
            .map { directory.appendingPathComponent($0) }
            .sorted { $0.creationDate < $1.creationDate }

        var recompressedCount = 0
        for file in files {
            if let limit, recompressedCount >= limit {
                break
            }
            guard let data = try? Data(contentsOf: file), !data.starts(with: compressionMagic) else {
                continue
            }
            do {
                try compress(data).write(to: file)
                recompressedCount += 1
            } catch {
                Log.error("recompressExistingBackups: \(error)")
            }
        }
        return recompressedCount
    }

    static func getFilesToDelete() -> [URL] {
        guard let directory = getBackupsDirectory(createIfMissing: false) else {
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
        let now = Date()
        let oneWeekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
        let halfYearAgo = calendar.date(byAdding: .month, value: -6, to: now)!
        let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: now)!

        var manualFiles = [URL]()
        var lastWeekFiles = [URL]()
        var weeklyBuckets = [String: URL]()
        var monthlyBuckets = [String: URL]()
        var halfYearlyBuckets = [String: URL]()

        func bucketKey(_ date: Date, _ component: Calendar.Component) -> String {
            let year = calendar.component(.year, from: date)
            let value = calendar.component(component, from: date)
            return "\(year)-\(value)"
        }

        for file in files {
            if file.lastPathComponent.contains("_m") {
                manualFiles.append(file)
                continue
            }

            let creationDate = file.creationDate

            if creationDate >= oneWeekAgo {
                lastWeekFiles.append(file)
            } else if creationDate >= halfYearAgo {
                let key = bucketKey(creationDate, .weekOfYear)
                if weeklyBuckets[key] == nil {
                    weeklyBuckets[key] = file
                }
            } else if creationDate >= oneYearAgo {
                let key = bucketKey(creationDate, .month)
                if monthlyBuckets[key] == nil {
                    monthlyBuckets[key] = file
                }
            } else {
                let year = calendar.component(.year, from: creationDate)
                let half = calendar.component(.month, from: creationDate) <= 6 ? 1 : 2
                let key = "\(year)-\(half)"
                if halfYearlyBuckets[key] == nil {
                    halfYearlyBuckets[key] = file
                }
            }
        }
        let keepers = manualFiles + lastWeekFiles
            + Array(weeklyBuckets.values) + Array(monthlyBuckets.values) + Array(halfYearlyBuckets.values)
        return files.filter { !keepers.contains($0) }
    }

    static func deleteFile(_ filepath: URL) {
        do {
            try FileManager.default.removeItem(at: filepath)
        } catch {
            Log.error("deleteFile: \(error)")
        }
    }

    static func getBackupsDirectory(createIfMissing: Bool = true) -> URL? {
        if let containerUrl = FileManager.default.url(
            forUbiquityContainerIdentifier: nil
        )?.appendingPathComponent("Documents/Backups") {
            Log.info("containerUrl \(containerUrl)")
            if !FileManager.default.fileExists(atPath: containerUrl.path, isDirectory: nil) {
                guard createIfMissing else {
                    Log.info("backupsDirectory: doesn't exist")
                    return nil
                }
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

    static func clearMemory() {
        Log.info("clearMemory")
        Task { @MainActor in
            BrowserManager.shared.releaseWebView()
            await ImageCacheManager.shared.clearMemory()
        }
    }
}

struct UnwatchedBackup: Codable {
    var settings: [String: AnyCodable]? = [:]
    var subscriptions   = [SendableSubscription]()
    var videos          = [SendableVideo]()
    var queueEntries    = [SendableQueueEntry]()
    var inboxEntries    = [SendableInboxEntry]()
    var channelStatistics: [SendableChannelStatistics]? = []

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
