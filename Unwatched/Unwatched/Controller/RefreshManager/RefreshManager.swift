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
            Log.info("currently refreshing, stopping now")
            return
        }

        defer {
            stopLoading()
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
            Log.info("Error during refresh: \(error)")
        }

        await cleanup(hardRefresh: hardRefresh)
    }

    func handleAutoBackup() {
        Log.info("handleAutoBackup")
        let lastAutoBackupDate = UserDefaults.standard.object(forKey: Const.lastAutoBackupDate) as? Date
        if let lastAutoBackupDate = lastAutoBackupDate {
            let calendar = Calendar.current
            if calendar.isDateInToday(lastAutoBackupDate) {
                Log.info("last backup was today")
                return
            }
        }

        let automaticBackups = UserDefaults.standard.object(forKey: Const.automaticBackups) as? Bool ?? true
        guard automaticBackups == true else {
            Log.info("no auto backup on")
            return
        }

        let task = UserDataService.saveToIcloud()
        Task {
            try await task.value
            UserDefaults.standard.set(Date(), forKey: Const.lastAutoBackupDate)
            Log.info("saved backup")

            // Auto delete
            if UserDefaults.standard.object(forKey: Const.autoDeleteBackups) as? Bool ?? true {
                _ = UserDataService.autoDeleteBackups()
            }
        }
    }

    func stopSyncIndicatorIfNoNetwork() async {
        if await !isNetworkConnected() {
            // workaround: sync event could be long, but they also happen offline
            // this stops the sync indicator only when there's no connection
            self.isSyncingIcloud = false
        }
    }

    func handleBecameActive() async {
        if cancellables.isEmpty {
            setupCloudKitListener()
        }
        Log.info("iCloud sync: refreshOnStartup started")
        let enableIcloudSync = UserDefaults.standard.bool(forKey: Const.enableIcloudSync)
        let autoRefreshIgnoresSync = UserDefaults.standard.bool(forKey: Const.autoRefreshIgnoresSync)

        if enableIcloudSync {
            let networkTimeout: CGFloat = 3
            if autoRefreshIgnoresSync {
                autoRefreshTask = Task {
                    await executeAutoRefresh()
                }
                do {
                    try await Task.sleep(s: networkTimeout)
                    await stopSyncIndicatorIfNoNetwork()
                } catch { }
                return
            }

            syncDoneTask?.cancel()
            syncDoneTask = Task {
                do {
                    // timeout in case CloudKit sync doesn't start
                    try await Task.sleep(s: networkTimeout)
                    autoRefreshTask?.cancel()
                    autoRefreshTask = Task { @MainActor in
                        await stopSyncIndicatorIfNoNetwork()
                        await executeAutoRefresh()
                    }
                } catch {
                    Log.info("error: \(error)")
                }
            }
        } else {
            cancelCloudKitListener()
            autoRefreshTask = Task {
                await executeAutoRefresh()
            }
        }
    }

    func handleBecameInactive() {
        Log.info("handleBecameInactive")
        cancelCloudKitListener()
        syncDoneTask?.cancel()
        autoRefreshTask?.cancel()
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

    func executeAutoRefresh() async {
        Log.info("iCloud sync: executeRefreshOnStartup refreshOnStartup")
        let autoRefresh = UserDefaults.standard.object(forKey: Const.autoRefresh) as? Bool ?? true

        if autoRefresh {
            let lastAutoRefreshDate = UserDefaults.standard.object(forKey: Const.lastAutoRefreshDate) as? Date
            let shouldRefresh = lastAutoRefreshDate == nil ||
                lastAutoRefreshDate!.timeIntervalSinceNow < -Const.autoRefreshIntervalSeconds
            if shouldRefresh {
                Log.info("refreshing now")
                await self.refreshAll()
            }
            await scheduleRepeatingRefresh()
        }
    }

    func scheduleRepeatingRefresh() async {
        do {
            try await Task.sleep(s: Const.autoRefreshIntervalSeconds)
            Log.info("scheduleRepeatingRefresh now")
            await self.executeAutoRefresh()
        } catch {
            Log.info("scheduleRepeatingRefresh cancelled/error: \(error)")
        }
    }
}

// Background Refresh
extension RefreshManager {
    #if os(iOS)
    func scheduleVideoRefresh() {
        Log.info("scheduleVideoRefresh()")
        let request = BGAppRefreshTaskRequest(identifier: Const.backgroundAppRefreshId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: Const.earliestBackgroundBeginSeconds)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            Log.info("Error scheduleVideoRefresh: \(error)")
        }
        Log.info("Scheduled background task") // Breakpoint 1 HERE

        // swiftlint:disable:next line_length
        // e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.pentlandFirth.Unwatched.refreshVideos"]

        // swiftlint:disable:next line_length
        // e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateExpirationForTaskWithIdentifier:@"com.pentlandFirth.Unwatched.refreshVideos"]
    }
    #endif

    func handleBackgroundVideoRefresh() async {
        #if os(iOS)
        print("Background task running now")
        do {
            scheduleVideoRefresh()

            NotificationManager.notifyRun(.setup)

            let canStartLoading = await refreshActor.startLoading()
            guard canStartLoading else {
                Log.info("Already refreshing")
                NotificationManager.notifyRun(.abort)
                return
            }

            defer {
                Task {
                    await refreshActor.stopLoading()
                    NotificationManager.notifyRun(.stopLoading)
                }
            }

            NotificationManager.notifyRun(.start)

            let task = VideoService.loadNewVideosInBg()
            let newVideos = try await task.value
            UserDefaults.standard.set(Date(), forKey: Const.lastAutoRefreshDate)
            if newVideos.videoCount > 0 {
                print("notifyNewVideos")
                await NotificationManager.notifyNewVideos(newVideos)
            }
            NotificationManager.notifyRun(.end)
        } catch {
            print("Error during background refresh: \(error)")
            NotificationManager.notifyRun(.error, error.localizedDescription)
        }
        #endif
    }
}
