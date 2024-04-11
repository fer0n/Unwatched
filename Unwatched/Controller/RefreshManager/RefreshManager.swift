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

@Observable class RefreshManager {
    weak var container: ModelContainer?
    @MainActor var isLoading: Bool = false
    @MainActor var isSyncingIcloud: Bool = false

    @ObservationIgnored var minimumAnimationDuration: Double = 0.5

    @ObservationIgnored var cancellables: Set<AnyCancellable> = []
    @ObservationIgnored var syncDoneTask: Task<(), Never>?

    var showError: ((_ error: any Error) -> Void)?

    init() {
        setupCloudKitListener()
    }

    deinit {
        cancelCloudKitListener()
    }

    func refreshAll(hardRefresh: Bool = false) async {
        cancelCloudKitListener()
        await refresh(hardRefresh: hardRefresh)
        UserDefaults.standard.set(Date(), forKey: Const.lastAutoRefreshDate)
    }

    func refreshSubscription(subscriptionId: PersistentIdentifier, hardRefresh: Bool = false) async {
        await refresh(subscriptionIds: [subscriptionId], hardRefresh: hardRefresh)
    }

    @MainActor
    private func refresh(subscriptionIds: [PersistentIdentifier]? = nil, hardRefresh: Bool = false) async {
        if let container = container {
            if isLoading { return }
            isLoading = true
            do {
                let task = VideoService.loadNewVideosInBg(subscriptionIds: subscriptionIds,
                                                          container: container)
                _ = try await task.value
            } catch {
                showError?(error)
            }
            isLoading = false
            if hardRefresh {
                _ = CleanupService.cleanupDuplicates(container, onlyIfDuplicateEntriesExist: false)
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
                    await executeRefreshOnStartup()
                } catch {
                    Logger.log.info("error: \(error)")
                }
            }
        } else {
            await executeRefreshOnStartup()
        }
    }

    func handleBecameInactive() {
        cancelCloudKitListener()
    }

    func executeRefreshOnStartup() async {
        Logger.log.info("iCloud sync: executeRefreshOnStartup refreshOnStartup")
        let refreshOnStartup = UserDefaults.standard.object(forKey: Const.refreshOnStartup) as? Bool ?? true

        if refreshOnStartup {
            let lastAutoRefreshDate = UserDefaults.standard.object(forKey: Const.lastAutoRefreshDate) as? Date
            let shouldRefresh = lastAutoRefreshDate == nil ||
                lastAutoRefreshDate!.timeIntervalSinceNow < -Const.autoRefreshIntervalSeconds

            if shouldRefresh {
                Logger.log.info("refreshing now")
                await self.refreshAll()
            }
            cancelCloudKitListener()
        }
    }
}

// Background Refresh
extension RefreshManager {
    static func scheduleVideoRefresh() {
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

    static func handleBackgroundVideoRefresh(_ container: ModelContainer) async {
        print("Background task running now")
        do {
            scheduleVideoRefresh()
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
                NotificationManager.increaseBadgeNumer(by: newVideos.videoCount)
                NotificationManager.notifyNewVideos(newVideos)
            }
        } catch {
            print("Error during background refresh: \(error)")
        }
    }
}
