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

    /// Events that have started but not reported an end yet. Counted rather than tracked as a bool:
    /// setup, import and export overlap, and an ending export would otherwise clear the indicator
    /// while an import is still running.
    @ObservationIgnored private var runningEvents = Set<UUID>()

    init() {
        setupCloudKitListener()
    }

    func setupCloudKitListener() {
        Log.info("iCloud sync: Setting up sync notification")
        NotificationCenter.default.publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
            .sink { [weak self] notification in
                guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                        as? NSPersistentCloudKitContainer.Event else {
                    return
                }
                let identifier = event.identifier
                let type = Self.name(for: event.type)
                let ended = event.endDate != nil
                let error = event.error?.localizedDescription
                Task { @MainActor in
                    self?.handleEvent(identifier, type: type, ended: ended, error: error)
                }
            }
            .store(in: &cancellables)
    }

    func cancelCloudKitListener() {
        Log.info("iCloud sync: cancelling sync notification")
        cancellables.removeAll()
    }

    @MainActor
    private func handleEvent(_ identifier: UUID, type: String, ended: Bool, error: String?) {
        if ended {
            runningEvents.remove(identifier)
            if let error {
                Log.error("iCloud sync: \(type) failed: \(error)")
            } else {
                Log.info("iCloud sync: \(type) done")
            }
        } else {
            runningEvents.insert(identifier)
            Log.info("iCloud sync: \(type) started")
        }

        let syncing = !runningEvents.isEmpty
        if isSyncing != syncing {
            isSyncing = syncing
        }
    }

    private static func name(for type: NSPersistentCloudKitContainer.EventType) -> String {
        switch type {
        case .setup: "setup"
        case .import: "import"
        case .export: "export"
        @unknown default: "unknown"
        }
    }
}
