//
//  IcloudBackupQuery.swift
//  Unwatched
//

import Foundation

@MainActor
final class IcloudBackupQuery {
    private struct Item {
        let url: URL
        let date: Date
        let isDownloaded: Bool
    }

    private let query = NSMetadataQuery()

    static func newestDownloadedBackup(timeout: Duration) async -> URL? {
        let backupQuery = IcloudBackupQuery()
        defer { backupQuery.query.stop() }
        return await backupQuery.run(until: .now + timeout)
    }

    private func run(until deadline: ContinuousClock.Instant) async -> URL? {
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K LIKE %@", NSMetadataItemFSNameKey, "*.unwatchedbackup")
        query.operationQueue = .main
        query.start()

        var requestedDownload: URL?
        while ContinuousClock.now < deadline, !Task.isCancelled {
            if !query.isGathering, let item = newestItem() {
                if item.isDownloaded {
                    return item.url
                }
                if requestedDownload != item.url {
                    try? FileManager.default.startDownloadingUbiquitousItem(at: item.url)
                    requestedDownload = item.url
                }
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
        return newestItem().flatMap { $0.isDownloaded ? $0.url : nil }
    }

    private func newestItem() -> Item? {
        query.disableUpdates()
        defer { query.enableUpdates() }
        return query.results
            .compactMap { result -> Item? in
                guard let item = result as? NSMetadataItem,
                      let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL,
                      let date = item.value(forAttribute: NSMetadataItemFSCreationDateKey) as? Date else {
                    return nil
                }
                let status = item.value(forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String
                return Item(url: url, date: date, isDownloaded: status == NSMetadataUbiquitousItemDownloadingStatusCurrent)
            }
            .max { $0.date < $1.date }
    }
}
