//
//  RefreshController.swift
//  Unwatched
//

import Foundation
import SwiftData

@Observable class RefreshManager {
    var container: ModelContainer?
    var isLoading: Bool = false
    var showLoadingAnimation: Bool = false

    @ObservationIgnored var loadingStart: Date?
    @ObservationIgnored var minimumAnimationDuration: Double = 0.5

    func refreshAll() {
        refresh()
        UserDefaults.standard.set(Date(), forKey: Const.lastAutoRefreshDate)
    }

    func refreshSubscription(subscriptionId: PersistentIdentifier) {
        refresh(subscriptionIds: [subscriptionId])
    }

    private func refresh(subscriptionIds: [PersistentIdentifier]? = nil) {
        if let container = container {
            if isLoading { return }
            isLoading = true
            loadingStart = .now
            showLoadingAnimation = true
            Task {
                let task = VideoService.loadNewVideosInBg(subscriptionIds: subscriptionIds, container: container)
                try? await task.value
                await MainActor.run {
                    isLoading = false
                }
                await disableLoadingAnimation()
            }
        }
    }

    private func disableLoadingAnimation() async {
        let timeSinceLoadingStart = loadingStart?.timeIntervalSinceNow ?? 0
        let duration = max(timeSinceLoadingStart + minimumAnimationDuration, 0)
        if duration > 0 {
            try? await Task.sleep(s: duration)
        }
        showLoadingAnimation = false
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

    func refreshOnStartup() {
        let refreshOnStartup = UserDefaults.standard.object(forKey: Const.refreshOnStartup) as? Bool ?? true

        if refreshOnStartup {
            let lastAutoRefreshDate = UserDefaults.standard.object(forKey: Const.lastAutoRefreshDate) as? Date
            let shouldRefresh = lastAutoRefreshDate == nil ||
                lastAutoRefreshDate!.timeIntervalSinceNow < -Const.autoRefreshIntervalSeconds

            if shouldRefresh {
                print("refreshing now")
                self.refreshAll()
            }
        }
    }
}
