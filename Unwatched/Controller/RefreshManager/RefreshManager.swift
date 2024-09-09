//
//  RefreshController.swift
//  Unwatched
//

import Foundation
import SwiftData
import Combine
import CoreData
import BackgroundTasks
import OSLog

@MainActor
@Observable class RefreshManager {
    weak var container: ModelContainer?
    var isLoading: Bool = false
    var isSyncingIcloud: Bool = false

    @ObservationIgnored var minimumAnimationDuration: Double = 0.5

    @ObservationIgnored var cancellables: Set<AnyCancellable> = []
    @ObservationIgnored var syncDoneTask: Task<(), Never>?

    @ObservationIgnored var autoRefreshTask: Task<(), Never>?

    var showError: ((_ error: any Error) -> Void)?

    init() {
        setupCloudKitListener()
    }

    deinit {
        Task {
            await cancelCloudKitListener()
        }
    }

    func refreshAll(hardRefresh: Bool = false) async {
        await refresh(hardRefresh: hardRefresh)
        UserDefaults.standard.set(Date(), forKey: Const.lastAutoRefreshDate)
    }

    func refreshSubscription(subscriptionId: PersistentIdentifier, hardRefresh: Bool = false) async {
        await refresh(subscriptionIds: [subscriptionId], hardRefresh: hardRefresh)
    }

    private func refresh(subscriptionIds: [PersistentIdentifier]? = nil, hardRefresh: Bool = false) async {
        if let container = container {
            if isLoading || self.isSyncingIcloud {
                Logger.log.info("currently refreshing or syncing, stopping now")
                return
            }
            isLoading = true
            do {
                let task = VideoService.loadNewVideosInBg(
                    subscriptionIds: subscriptionIds,
                    container: container
                )
                _ = try await task.value
            } catch {
                showError?(error)
            }
            isLoading = false
            if hardRefresh {
                _ = CleanupService.cleanupDuplicatesAndInboxDate(container, onlyIfDuplicateEntriesExist: false)
            } else {
                quickDuplicateCleanup()
            }
        }
    }

    func handleAutoBackup(_ deviceName: String) {
        Logger.log.info("handleAutoBackup")
        let lastAutoBackupDate = UserDefaults.standard.object(forKey: Const.lastAutoBackupDate) as? Date
        if let lastAutoBackupDate = lastAutoBackupDate {
            let calendar = Calendar.current
            if calendar.isDateInToday(lastAutoBackupDate) {
                Logger.log.info("last backup was today")
                return
            }
        }

        let automaticBackups = UserDefaults.standard.object(forKey: Const.automaticBackups) as? Bool ?? true
        guard automaticBackups == true else {
            Logger.log.info("no auto backup on")
            return
        }

        if let container = container {
            let task = UserDataService.saveToIcloud(deviceName, container)
            Task {
                try await task.value
                UserDefaults.standard.set(Date(), forKey: Const.lastAutoBackupDate)
                Logger.log.info("saved backup")

                // Auto delete
                if UserDefaults.standard.object(forKey: Const.autoDeleteBackups) as? Bool ?? true {
                    _ = UserDataService.autoDeleteBackups()
                }
            }
        }
    }

    func handleBecameActive() async {
        if cancellables.isEmpty {
            setupCloudKitListener()
        }
        Logger.log.info("iCloud sync: refreshOnStartup started")
        let enableIcloudSync = UserDefaults.standard.bool(forKey: Const.enableIcloudSync)
        if enableIcloudSync {
            syncDoneTask?.cancel()
            syncDoneTask = Task {
                do {
                    // timeout in case CloudKit sync doesn't start
                    try await Task.sleep(s: 3)
                    autoRefreshTask?.cancel()
                    autoRefreshTask = Task {
                        self.isSyncingIcloud = false
                        await executeRefreshOnStartup()
                    }
                } catch {
                    Logger.log.info("error: \(error)")
                }
            }
        } else {
            cancelCloudKitListener()
            autoRefreshTask = Task {
                await executeRefreshOnStartup()
            }
        }
    }

    func handleBecameInactive() {
        autoRefreshTask?.cancel()
    }

    func executeRefreshOnStartup() async {
        Logger.log.info("iCloud sync: executeRefreshOnStartup refreshOnStartup")
        let autoRefresh = UserDefaults.standard.object(forKey: Const.autoRefresh) as? Bool ?? true

        if autoRefresh {
            let lastAutoRefreshDate = UserDefaults.standard.object(forKey: Const.lastAutoRefreshDate) as? Date
            let shouldRefresh = lastAutoRefreshDate == nil ||
                lastAutoRefreshDate!.timeIntervalSinceNow < -Const.autoRefreshIntervalSeconds
            if shouldRefresh {
                Logger.log.info("refreshing now")
                await self.refreshAll()
            }
            await scheduleRepeatingRefresh()
        }
    }

    func scheduleRepeatingRefresh() async {
        do {
            try await Task.sleep(s: Const.autoRefreshIntervalSeconds)
            Logger.log.info("scheduleRepeatingRefresh now")
            await self.executeRefreshOnStartup()
        } catch {
            Logger.log.info("scheduleRepeatingRefresh cancelled/error: \(error)")
        }
    }
}

// Background Refresh
extension RefreshManager {
    func scheduleVideoRefresh() {
        Logger.log.info("scheduleVideoRefresh()")
        let request = BGAppRefreshTaskRequest(identifier: Const.backgroundAppRefreshId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: Const.earliestBackgroundBeginSeconds)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            Logger.log.info("Error scheduleVideoRefresh: \(error)")
        }
        Logger.log.info("Scheduled background task") // Breakpoint 1 HERE

        // swiftlint:disable:next line_length
        // e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.pentlandFirth.Unwatched.refreshVideos"]

        // swiftlint:disable:next line_length
        // e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateExpirationForTaskWithIdentifier:@"com.pentlandFirth.Unwatched.refreshVideos"]
    }

    func handleBackgroundVideoRefresh() async {
        print("Background task running now")
        guard let container = container else {
            print("no container to refresh in background")
            return
        }
        do {
            scheduleVideoRefresh()

            if isLoading {
                Logger.log.info("Already refreshing")
                return
            }

            let task = VideoService.loadNewVideosInBg(container: container)
            let newVideos = try await task.value
            UserDefaults.standard.set(Date(), forKey: Const.lastAutoRefreshDate)
            if Task.isCancelled {
                print("background task has been cancelled")
            }
            if newVideos.videoCount == 0 {
                print("notifyHasRun")
                NotificationManager.notifyHasRun()
            } else {
                print("notifyNewVideos")
                NotificationManager.changeBadgeNumer(by: newVideos.videoCount)
                await NotificationManager.notifyNewVideos(newVideos, container: container)
            }
        } catch {
            print("Error during background refresh: \(error)")
        }
    }
}
