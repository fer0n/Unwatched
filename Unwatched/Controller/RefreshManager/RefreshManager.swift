//
//  RefreshController.swift
//  Unwatched
//

import Foundation
import SwiftData
import Combine
import CoreData
import BackgroundTasks

@Observable class RefreshManager {
    weak var container: ModelContainer?
    @MainActor var isLoading: Bool = false
    @MainActor var isSyncingIcloud: Bool = false

    @ObservationIgnored var minimumAnimationDuration: Double = 0.5

    @ObservationIgnored var cancellables: Set<AnyCancellable> = []
    @ObservationIgnored var syncDoneTask: Task<(), Never>?

    init() {
        setupCloudKitListener()
    }

    deinit {
        cancelCloudKitListener()
    }

    func refreshAll() async {
        cancelCloudKitListener()
        await refresh()
        UserDefaults.standard.set(Date(), forKey: Const.lastAutoRefreshDate)
    }

    func refreshSubscription(subscriptionId: PersistentIdentifier) async {
        await refresh(subscriptionIds: [subscriptionId])
    }

    @MainActor
    private func refresh(subscriptionIds: [PersistentIdentifier]? = nil) async {
        if let container = container {
            if isLoading { return }
            isLoading = true
            let task = VideoService.loadNewVideosInBg(subscriptionIds: subscriptionIds, container: container)
            _ = try? await task.value
            isLoading = false
            quickDuplicateCleanup()
        }
    }

    func handleAutoBackup(_ deviceName: String) {
        print("handleAutoBackup")
        let lastAutoBackupDate = UserDefaults.standard.object(forKey: Const.lastAutoBackupDate) as? Date
        if let lastAutoBackupDate = lastAutoBackupDate {
            let calendar = Calendar.current
            if calendar.isDateInToday(lastAutoBackupDate) {
                print("last backup was today")
                return
            }
        }

        let automaticBackups = UserDefaults.standard.object(forKey: Const.automaticBackups) as? Bool ?? true
        guard automaticBackups == true else {
            print("no auto backup on")
            return
        }

        if let container = container {
            let task = UserDataService.saveToIcloud(deviceName, container)
            Task {
                try await task.value
                UserDefaults.standard.set(Date(), forKey: Const.lastAutoBackupDate)
                print("saved backup")
            }
        }
    }

    func handleBecameActive() async {
        if cancellables.isEmpty {
            setupCloudKitListener()
        }
        print("iCloud sync: refreshOnStartup started")
        let enableIcloudSync = UserDefaults.standard.bool(forKey: Const.enableIcloudSync)
        if enableIcloudSync {
            syncDoneTask?.cancel()
            syncDoneTask = Task {
                do {
                    // timeout in case CloudKit sync doesn't start
                    try await Task.sleep(s: 3)
                    await executeRefreshOnStartup()
                } catch {
                    print("error: \(error)")
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
        print("iCloud sync: executeRefreshOnStartup refreshOnStartup")
        let refreshOnStartup = UserDefaults.standard.object(forKey: Const.refreshOnStartup) as? Bool ?? true

        if refreshOnStartup {
            let lastAutoRefreshDate = UserDefaults.standard.object(forKey: Const.lastAutoRefreshDate) as? Date
            let shouldRefresh = lastAutoRefreshDate == nil ||
                lastAutoRefreshDate!.timeIntervalSinceNow < -Const.autoRefreshIntervalSeconds

            if shouldRefresh {
                print("refreshing now")
                await self.refreshAll()
            }
            cancelCloudKitListener()
        }
    }
}

// Background Refresh
// extension RefreshManager {
//    static func scheduleVideoRefresh() {
//        print("scheduleVideoRefresh()")
//        // let request = BGAppRefreshTaskRequest(identifier: Const.backgroundAppRefreshId)
//        // request.earliestBeginDate = Date(timeIntervalSinceNow: Const.earliestBackgroundBeginSeconds)
//        // do {
//        //     try BGTaskScheduler.shared.submit(request)
//        // } catch {
//        //     print("Error scheduleVideoRefresh: \(error)")
//        // }
//        // print("Scheduled background task") // Breakpoint 1 HERE
//
//        // swiftlint:disable:next line_length
//        // e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.pentlandFirth.Unwatched.refreshVideos"]
//
//        // swiftlint:disable:next line_length
//        // e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateExpirationForTaskWithIdentifier:@"com.pentlandFirth.Unwatched.refreshVideos"]
//    }
//
//    static func handleBackgroundVideoRefresh(_ container: ModelContainer) async {
//        print("Background task running now")
//        do {
//            scheduleVideoRefresh()
//            let task = VideoService.loadNewVideosInBg(container: container)
//            let newVideos = try await task.value
//            UserDefaults.standard.set(Date(), forKey: Const.lastAutoRefreshDate)
//            if Task.isCancelled {
//                print("background task has been cancelled")
//            }
//            if newVideos.videoCount == 0 {
//                print("notifyHasRun")
//                NotificationManager.notifyHasRun()
//            } else {
//                print("notifyNewVideos")
//                NotificationManager.increaseBadgeNumer(by: newVideos.videoCount)
//                NotificationManager.notifyNewVideos(newVideos)
//            }
//        } catch {
//            print("Error during background refresh: \(error)")
//        }
//    }
// }
