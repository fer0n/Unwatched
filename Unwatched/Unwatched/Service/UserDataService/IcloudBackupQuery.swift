//
//  IcloudBackupQuery.swift
//  Unwatched
//

import Foundation

struct IcloudBackup: Equatable {
    let url: URL
    let date: Date
    var isDownloaded = true
}

@MainActor
final class IcloudBackupQuery {
    private let query = NSMetadataQuery()

    init() {
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K LIKE %@", NSMetadataItemFSNameKey, "*.unwatchedbackup")
        query.operationQueue = .main
        query.start()
    }

    func stop() {
        query.stop()
    }

    func newestDownloadedBackup(until deadline: ContinuousClock.Instant) async -> IcloudBackup? {
        var requestedDownload: URL?
        while ContinuousClock.now < deadline, !Task.isCancelled {
            if !query.isGathering, let newest = newestBackup() {
                if newest.isDownloaded {
                    return newest
                }
                if requestedDownload != newest.url {
                    try? FileManager.default.startDownloadingUbiquitousItem(at: newest.url)
                    requestedDownload = newest.url
                }
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
        return newestBackup().flatMap { $0.isDownloaded ? $0 : nil }
    }

    func download(_ backup: IcloudBackup, until deadline: ContinuousClock.Instant) async -> Bool {
        if isDownloaded(backup) {
            return true
        }
        guard ContinuousClock.now < deadline, !Task.isCancelled,
              (try? FileManager.default.startDownloadingUbiquitousItem(at: backup.url)) != nil else {
            return false
        }
        while ContinuousClock.now < deadline, !Task.isCancelled {
            if isDownloaded(backup) {
                return true
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
        return isDownloaded(backup)
    }

    func backups() -> [IcloudBackup] {
        query.disableUpdates()
        defer { query.enableUpdates() }
        return query.results.compactMap { result -> IcloudBackup? in
            guard let item = result as? NSMetadataItem,
                  let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL,
                  let date = item.value(forAttribute: NSMetadataItemFSCreationDateKey) as? Date else {
                return nil
            }
            let status = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String
            return IcloudBackup(
                url: url,
                date: date,
                isDownloaded: status == NSMetadataUbiquitousItemDownloadingStatusCurrent
            )
        }
    }

    private func newestBackup() -> IcloudBackup? {
        backups().max { $0.date < $1.date }
    }

    private func isDownloaded(_ backup: IcloudBackup) -> Bool {
        backups().first { $0.url == backup.url }?.isDownloaded == true
    }
}
