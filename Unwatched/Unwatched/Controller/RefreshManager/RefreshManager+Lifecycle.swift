//
//  RefreshManager+Lifecycle.swift
//  Unwatched
//

import Foundation
import Network
import OSLog
import UnwatchedShared

extension RefreshManager {
    func handleBecameActive() async {
        guard !isActive else {
            return
        }
        isActive = true
        setupCloudKitListener()
        Log.info("iCloud sync: refreshOnStartup started")
        if Const.requiresDurationFetch.bool ?? false {
            VideoService.fetchVideoDurationsQueueInbox()
            UserDefaults.standard.set(false, forKey: Const.requiresDurationFetch)
        }
        PodcastDownloadManager.shared.scheduleSync()

        guard enableIcloudSync else {
            cancelCloudKitListener()
            autoRefreshTask = Task {
                await executeAutoRefresh()
            }
            return
        }

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
    }

    func handleBecameInactive() {
        Log.info("handleBecameInactive")
        isActive = false
        #if !os(macOS)
        cancelCloudKitListener()
        #endif
        syncDoneTask?.cancel()
        autoRefreshTask?.cancel()
        repeatingRefreshTask?.cancel()
    }

    func handleAutoBackup() {
        Log.info("handleAutoBackup")
        guard !isBackingUp else {
            return
        }
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
        isBackingUp = true
        Task {
            defer { isBackingUp = false }
            try await task.value
            UserDefaults.standard.set(Date(), forKey: Const.lastAutoBackupDate)
            Log.info("saved backup")

            // Auto delete
            if UserDefaults.standard.object(forKey: Const.autoDeleteBackups) as? Bool ?? true {
                _ = await UserDataService.autoDeleteBackups(recompressLimit: Const.autoRecompressBackupLimit)
            }
        }
    }

    func executeAutoRefresh() async {
        Log.info("iCloud sync: executeRefreshOnStartup refreshOnStartup")
        let autoRefresh = UserDefaults.standard.object(forKey: Const.autoRefresh) as? Bool ?? true
        guard autoRefresh else {
            return
        }

        let lastAutoRefreshDate = UserDefaults.standard.object(forKey: Const.lastAutoRefreshDate) as? Date
        let shouldRefresh = lastAutoRefreshDate == nil ||
            lastAutoRefreshDate!.timeIntervalSinceNow < -Const.autoRefreshIntervalSeconds
        if shouldRefresh {
            Log.info("refreshing now")
            await refreshAll(source: .automatic)
        }
        scheduleRepeatingRefresh()
    }

    func scheduleRepeatingRefresh() {
        repeatingRefreshTask?.cancel()
        repeatingRefreshTask = Task { @MainActor in
            do {
                try await Task.sleep(s: Const.autoRefreshIntervalSeconds)
                Log.info("scheduleRepeatingRefresh now")
                await self.executeAutoRefresh()
            } catch {
                Log.info("scheduleRepeatingRefresh cancelled/error: \(error)")
            }
        }
    }

    func stopSyncIndicatorIfNoNetwork() async {
        if await !isNetworkConnected() {
            // Workaround: sync events can be long, but they also happen offline. Remove once
            // CloudKit reports an offline sync as ended.
            clearSyncState()
        }
    }

    func isNetworkConnected() async -> Bool {
        await withUnsafeContinuation { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                monitor.cancel()
                continuation.resume(returning: path.status == .satisfied)
            }
            monitor.start(queue: DispatchQueue.global())
        }
    }
}
