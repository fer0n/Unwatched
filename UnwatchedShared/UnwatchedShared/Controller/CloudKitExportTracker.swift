//
//  CloudKitExportTracker.swift
//  UnwatchedShared
//

import Foundation
import CoreData
import SwiftData
import OSLog

@MainActor
public final class CloudKitExportTracker {
    public static let shared = CloudKitExportTracker()

    private var isStarted = false
    private var isCloudKitSetUp = false
    private var lastLocalSave: Date?
    private var savesExportedBefore = Date.distantPast
    private var runningExports = [UUID: Date]()

    private var hasPendingExport: Bool {
        guard isCloudKitSetUp else { return false }
        if !runningExports.isEmpty { return true }
        guard let lastLocalSave else { return false }
        return lastLocalSave >= savesExportedBefore
    }

    public func start() {
        guard !isStarted else { return }
        isStarted = true
        let center = NotificationCenter.default
        // CloudKit imports don't post ModelContext.didSave
        center.addObserver(forName: ModelContext.didSave, object: nil, queue: .main) { notification in
            let container = (notification.object as? ModelContext)?.container
            MainActor.assumeIsolated {
                CloudKitExportTracker.shared.handleLocalSave(in: container)
            }
        }
        center.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event else {
                return
            }
            let id = event.identifier
            let type = event.type
            let startDate = event.startDate
            let ended = event.endDate != nil
            let succeeded = event.succeeded
            MainActor.assumeIsolated {
                CloudKitExportTracker.shared.handleEvent(
                    id, type: type, startDate: startDate, ended: ended, succeeded: succeeded
                )
            }
        }
    }

    private func handleLocalSave(in container: ModelContainer?) {
        guard container === DataProvider.shared.container else { return }
        lastLocalSave = max(lastLocalSave ?? .distantPast, .now)
    }

    private func handleEvent(
        _ id: UUID,
        type: NSPersistentCloudKitContainer.EventType,
        startDate: Date,
        ended: Bool,
        succeeded: Bool
    ) {
        switch type {
        case .setup:
            if ended, succeeded { isCloudKitSetUp = true }
        case .export:
            isCloudKitSetUp = true
            guard ended else {
                runningExports[id] = startDate
                return
            }
            runningExports[id] = nil
            // a failed export is retried with backoff, too late to wait for
            savesExportedBefore = max(savesExportedBefore, startDate)
        default:
            break
        }
    }

    public func waitForPendingExport(timeout: Duration) async {
        guard hasPendingExport else {
            Log.sync.info("terminate: nothing left to export")
            return
        }
        Log.sync.info("terminate: waiting for CloudKit export")
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while hasPendingExport, clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
        Log.sync.info("terminate: export \(self.hasPendingExport ? "timed out" : "done")")
    }
}
