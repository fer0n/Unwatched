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

        Logger.log.info("iCloud sync: Setting up sync notification")
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
                                try await Task.sleep(s: 3)
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
        Logger.log.info("iCloud sync: cancelling sync notification")
        cancellables.removeAll()
    }

    func handleIcloudSyncDone() async {
        Logger.log.info("iCloud sync: handleIcloudSyncDone")
        let task = Task { @MainActor in
            self.isSyncingIcloud = false
        }
        await task.value
        await executeAutoRefresh()
    }

    func cleanup(
        hardRefresh: Bool,
        _ container: ModelContainer
    ) async {
        if hardRefresh {
            let task = CleanupService.cleanupDuplicatesAndInboxDate(container, quickCheck: false)
            _ = await task.value
        } else {
            await quickCleanup(container)
        }
    }

    private func quickCleanup(_ container: ModelContainer) async {
        let enableIcloudSync = UserDefaults.standard.bool(forKey: Const.enableIcloudSync)
        guard enableIcloudSync else {
            return
        }
        Logger.log.info("quickCleanup")

        let task = CleanupService.cleanupDuplicatesAndInboxDate(container, quickCheck: true)
        _ = await task.value
    }
}
