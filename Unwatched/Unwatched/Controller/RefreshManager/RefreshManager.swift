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
import UnwatchedShared
import Network

actor RefreshActor {
    private var isLoading: Bool = false

    func startLoading() -> Bool {
        if isLoading {
            return false
        } else {
            isLoading = true
            return true
        }
    }

    func stopLoading() {
        isLoading = false
    }
}

@MainActor
@Observable class RefreshManager {
    static let shared = RefreshManager()

    var isLoading = false
    var isSyncingIcloud = false

    @ObservationIgnored var triggerPasteAction = false

    func consumeTriggerPasteAction() -> Bool {
        if triggerPasteAction {
            triggerPasteAction = false
            return true
        }
        return false
    }

    @ObservationIgnored var minimumAnimationDuration: Double = 0.5

    @ObservationIgnored var cancellables: Set<AnyCancellable> = []
    @ObservationIgnored var syncDoneTask: Task<(), Never>?

    @ObservationIgnored var autoRefreshTask: Task<(), Never>?

    private let refreshActor = RefreshActor()

    init() {
        setupCloudKitListener()
    }

    func refreshAll(hardRefresh: Bool = false) async {
        await refresh(hardRefresh: hardRefresh)
    }

    func refreshSubscription(subscriptionId: PersistentIdentifier, hardRefresh: Bool = false) async {
        await refresh(subscriptionIds: [subscriptionId], hardRefresh: hardRefresh)
    }

    func startLoading() async -> Bool {
        isLoading = true
        let canStartLoading = await refreshActor.startLoading()
        return canStartLoading
    }

    func stopLoading() {
        isLoading = false
        Task {
            await refreshActor.stopLoading()
        }
    }

    private func refresh(subscriptionIds: [PersistentIdentifier]? = nil, hardRefresh: Bool = false) async {
        let canStartLoading = await startLoading()
        guard canStartLoading else {
            Logger.log.info("currently refreshing, stopping now")
            return
        }

        if subscriptionIds?.isEmpty ?? true {
            UserDefaults.standard.set(Date(), forKey: Const.lastAutoRefreshDate)
        }
        do {
            let task = VideoService.loadNewVideosInBg(
                subscriptionIds: subscriptionIds
            )
            _ = try await task.value
        } catch {
            Logger.log.info("Error during refresh: \(error)")
            stopLoading()
        }

        await cleanup(hardRefresh: hardRefresh)

        stopLoading()
    }

    func handleAutoBackup() {
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

        let task = UserDataService.saveToIcloud()
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
                    autoRefreshTask = Task { @MainActor in
                        if await !isNetworkConnected() {
                            // workaround: sync event could be long, but they also happen offline
                            // this stops the sync indicator only when there's no connection
                            self.isSyncingIcloud = false
                        }
                        await executeAutoRefresh()
                    }
                } catch {
                    Logger.log.info("error: \(error)")
                    stopLoading()
                }
            }
        } else {
            cancelCloudKitListener()
            autoRefreshTask = Task {
                await executeAutoRefresh()
            }
        }
    }

    func isNetworkConnected() async -> Bool {
        return await withUnsafeContinuation { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                monitor.cancel()
                continuation.resume(returning: path.status == .satisfied)
            }
            monitor.start(queue: DispatchQueue.global())
        }
    }

    func handleBecameInactive() {
        autoRefreshTask?.cancel()
    }

    func executeAutoRefresh() async {
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
            await self.executeAutoRefresh()
        } catch {
            Logger.log.info("scheduleRepeatingRefresh cancelled/error: \(error)")
            stopLoading()
        }
    }
}

// Background Refresh
extension RefreshManager {
    func scheduleVideoRefresh() {
        #if os(iOS)
        Logger.log.info("scheduleVideoRefresh()")
        do {
            let request = BGAppRefreshTaskRequest(identifier: Const.backgroundAppRefreshId)
            request.earliestBeginDate = Date(timeIntervalSinceNow: Const.earliestBackgroundBeginSeconds)
            try BGTaskScheduler.shared.submit(request)
        } catch {
            Logger.log.info("Error scheduleVideoRefresh: \(error)")
        }
        Logger.log.info("Scheduled background task") // Breakpoint 1 HERE

        // swiftlint:disable:next line_length
        // e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.pentlandFirth.Unwatched.refreshVideos"]

        // swiftlint:disable:next line_length
        // e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateExpirationForTaskWithIdentifier:@"com.pentlandFirth.Unwatched.refreshVideos"]
        #endif
    }

    func handleBackgroundVideoRefresh() async {
        print("Background task running now")
        do {
            scheduleVideoRefresh()

            #if os(iOS)
            NotificationManager.notifyRun(.start)
            #endif

            let canStartLoading = await refreshActor.startLoading()
            guard canStartLoading else {
                Logger.log.info("Already refreshing")
                #if os(iOS)
                NotificationManager.notifyRun(.abort)
                #endif
                return
            }

            defer {
                Task {
                    await refreshActor.stopLoading()
                }
            }

            let task = VideoService.loadNewVideosInBg()
            let newVideos = try await task.value
            UserDefaults.standard.set(Date(), forKey: Const.lastAutoRefreshDate)
            if Task.isCancelled {
                print("background task has been cancelled")
                #if os(iOS)
                NotificationManager.notifyRun(.cancel)
                #endif
            }
            #if os(iOS)
            if newVideos.videoCount > 0 {
                print("notifyNewVideos")
                NotificationManager.changeBadgeNumer(by: newVideos.videoCount)
                await NotificationManager.notifyNewVideos(newVideos)
            }
            NotificationManager.notifyRun(.end)
            #endif
        } catch {
            print("Error during background refresh: \(error)")
        }
    }
}
