//
//  SyncManager.swift
//  UnwatchedTV
//

import SwiftUI
import Observation
import Combine
import OSLog
import CoreData
import UnwatchedShared

@Observable class SyncManager {
    var isSyncing = false

    @ObservationIgnored var cancellables: Set<AnyCancellable> = []

    init() {
        setupCloudKitListener()
    }

    func setupCloudKitListener() {
        print("iCloud sync: Setting up sync notification")
        NotificationCenter.default.publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
            .sink { [weak self] notification in
                guard let self else { return }

                if let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event {

                    // print("iCloud sync: cancelled syncDoneTask")
                    if event.endDate == nil {
                        Task { @MainActor in
                            self.isSyncing = true
                        }
                        // starting event
                    }
                }
            }
            .store(in: &cancellables)
    }

    func cancelCloudKitListener() {
        print("iCloud sync: cancelling sync notification")
        cancellables.removeAll()
    }

}
