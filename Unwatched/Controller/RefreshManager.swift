//
//  RefreshController.swift
//  Unwatched
//

import Foundation
import SwiftData
import BackgroundTasks
import OSLog

private let log = Logger(subsystem: Const.bundleId, category: "RefreshManager")

@Observable class RefreshManager {
    weak var container: ModelContainer?
    @MainActor var isLoading: Bool = false

    @ObservationIgnored var loadingStart: Date?
    @ObservationIgnored var minimumAnimationDuration: Double = 0.5

    func refreshAll() async {
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
            loadingStart = .now
            let task = VideoService.loadNewVideosInBg(subscriptionIds: subscriptionIds, container: container)
            _ = try? await task.value
            isLoading = false
        }
    }

    func handleAutoBackup(_ deviceName: String) {
        log.info("handleAutoBackup")
        let lastAutoBackupDate = UserDefaults.standard.object(forKey: Const.lastAutoBackupDate) as? Date
        if let lastAutoBackupDate = lastAutoBackupDate {
            let calendar = Calendar.current
            if calendar.isDateInToday(lastAutoBackupDate) {
                log.info("last backup was today")
                return
            }
        }

        let automaticBackups = UserDefaults.standard.object(forKey: Const.automaticBackups) as? Bool ?? true
        guard automaticBackups == true else {
            log.info("no auto backup on")
            return
        }

        if let container = container {
            let task = UserDataService.saveToIcloud(deviceName, container)
            Task {
                try await task.value
                UserDefaults.standard.set(Date(), forKey: Const.lastAutoBackupDate)
                log.info("saved backup")
            }
        }
    }

    func refreshOnStartup() async {
        let refreshOnStartup = UserDefaults.standard.object(forKey: Const.refreshOnStartup) as? Bool ?? true

        if refreshOnStartup {
            let lastAutoRefreshDate = UserDefaults.standard.object(forKey: Const.lastAutoRefreshDate) as? Date
            let shouldRefresh = lastAutoRefreshDate == nil ||
                lastAutoRefreshDate!.timeIntervalSinceNow < -Const.autoRefreshIntervalSeconds

            if shouldRefresh {
                log.info("refreshing now")
                await self.refreshAll()
            }
        }
    }

    static func scheduleVideoRefresh() {
        log.info("scheduleVideoRefresh()")
        let request = BGAppRefreshTaskRequest(identifier: Const.backgroundAppRefreshId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: Const.earliestBackgroundBeginSeconds)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            log.error("Error scheduleVideoRefresh: \(error)")
        }
        log.info("Scheduled background task") // Breakpoint 1 HERE

        // swiftlint:disable:next line_length
        // e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.pentlandFirth.Unwatched.refreshVideos"]

        // swiftlint:disable:next line_length
        // e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateExpirationForTaskWithIdentifier:@"com.pentlandFirth.Unwatched.refreshVideos"]
    }

    static func handleBackgroundVideoRefresh(_ container: ModelContainer) async {
        log.info("Background task running now")
        do {
            let task = VideoService.loadNewVideosInBg(container: container)
            let newVideos = try await task.value
            UserDefaults.standard.set(Date(), forKey: Const.lastAutoRefreshDate)
            if Task.isCancelled {
                log.info("background task has been cancelled")
            }

            if newVideos.videoCount == 0 {
                log.info("notifyHasRun")
                NotificationManager.notifyHasRun()
            } else {
                log.info("notifyNewVideos")
                NotificationManager.notifyNewVideos(newVideos)
            }
            scheduleVideoRefresh()
        } catch {
            log.error("Error during background refresh: \(error)")
        }
    }
}
