//
//  RefreshManager+CloudKit.swift
//  Unwatched
//

import Foundation
import OSLog
import CoreData
import SwiftData
import UnwatchedShared

extension RefreshManager {
    func setupCloudKitListener() {
        guard enableIcloudSync, cancellables.isEmpty else {
            return
        }

        Log.info("iCloud sync: Setting up sync notification")
        NotificationCenter.default.publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
            .sink { [weak self] notification in
                guard let self,
                      let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                        as? NSPersistentCloudKitContainer.Event else {
                    return
                }

                syncDoneTask?.cancel()
                if event.endDate == nil {
                    Task { @MainActor in
                        if !self.isSyncingIcloud {
                            self.isSyncingIcloud = true
                            self.syncStartedAt = .now
                        }
                    }
                } else {
                    syncDoneTask = Task {
                        do {
                            try await Task.sleep(for: .seconds(3))
                            await self.handleIcloudSyncDone()
                        } catch { }
                    }
                }
            }
            .store(in: &cancellables)
    }

    func cancelCloudKitListener() {
        Log.info("iCloud sync: cancelling sync notification")
        cancellables.removeAll()
        clearSyncState()
    }

    func handleIcloudSyncDone() async {
        Log.info("iCloud sync: handleIcloudSyncDone")
        clearSyncState()
        PlayerManager.shared.handlePotentialUpdate()
        HistoryMaintenance.pruneConsumedHistoryIfDue()
        if pendingQuickCleanup {
            await quickCleanup()
        }
        if !autoRefreshIgnoresSync {
            await executeAutoRefresh()
        }
    }

    func cleanup(
        hardRefresh: Bool
    ) async {
        if hardRefresh {
            let task = CleanupService.cleanupDuplicatesAndInboxDate(quickCheck: false, videoOnly: false)
            _ = await task.value
        } else {
            await quickCleanup()
        }
    }

    private func quickCleanup() async {
        guard enableIcloudSync else {
            return
        }
        guard !shouldDeferForSync else {
            Log.info("quickCleanup deferred, iCloud sync in progress")
            pendingQuickCleanup = true
            return
        }
        pendingQuickCleanup = false
        Log.info("quickCleanup")

        let task = CleanupService.cleanupDuplicatesAndInboxDate(quickCheck: true)
        _ = await task.value
    }
}
