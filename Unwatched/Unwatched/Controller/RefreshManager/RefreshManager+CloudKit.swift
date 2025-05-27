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
        let enableIcloudSync = UserDefaults.standard.bool(forKey: Const.enableIcloudSync)
        guard enableIcloudSync else {
            return
        }

        Log.info("iCloud sync: Setting up sync notification")
        NotificationCenter.default.publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
            .sink { [weak self] notification in
                guard let self else { return }

                if let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event {

                    syncDoneTask?.cancel()
                    // print("iCloud sync: cancelled syncDoneTask")
                    if event.endDate == nil {
                        Task { @MainActor in
                            if !self.isSyncingIcloud {
                                self.isSyncingIcloud = true
                            }
                        }
                        // starting event
                    } else {
                        // print("iCloud sync: STOP: \(event.type)")
                        syncDoneTask = Task {
                            do {
                                try await Task.sleep(for: .seconds(3))
                                await self.handleIcloudSyncDone()
                            } catch {
                                // task cancelled
                            }
                        }
                        // event done
                    }
                }
            }
            .store(in: &cancellables)
    }

    func cancelCloudKitListener() {
        Log.info("iCloud sync: cancelling sync notification")
        cancellables.removeAll()
    }

    func handleIcloudSyncDone() async {
        Log.info("iCloud sync: handleIcloudSyncDone")
        let task = Task { @MainActor in
            self.isSyncingIcloud = false
        }
        await task.value
        PlayerManager.shared.handlePotentialUpdate()
        let autoRefreshIgnoresSync = UserDefaults.standard.bool(forKey: Const.autoRefreshIgnoresSync)
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
        let enableIcloudSync = UserDefaults.standard.bool(forKey: Const.enableIcloudSync)
        guard enableIcloudSync else {
            return
        }
        Log.info("quickCleanup")

        let task = CleanupService.cleanupDuplicatesAndInboxDate(quickCheck: true)
        _ = await task.value
    }
}
