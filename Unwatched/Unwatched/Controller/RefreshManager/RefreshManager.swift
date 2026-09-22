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

enum RefreshSource {
    /// Never deferred, whatever iCloud is doing.
    case manual
    case automatic
}

@MainActor
@Observable class RefreshManager {
    static let shared = RefreshManager()

    var isLoading = false
    var isSyncingIcloud = false

    var failedSubscriptionsCount = 0
    var totalSubscriptionsCount = 0

    @ObservationIgnored var triggerPasteAction = false
    @ObservationIgnored var triggerPasteAndQueueAction = false
    @ObservationIgnored var triggerSearchYoutube = false

    @ObservationIgnored var minimumAnimationDuration: Double = 0.5

    @ObservationIgnored var cancellables: Set<AnyCancellable> = []
    @ObservationIgnored var syncDoneTask: Task<(), Never>?

    @ObservationIgnored var autoRefreshTask: Task<(), Never>?
    @ObservationIgnored var repeatingRefreshTask: Task<(), Never>?

    @ObservationIgnored var pendingQuickCleanup = false
    @ObservationIgnored var syncStartedAt: Date?
    @ObservationIgnored var isActive = false
    @ObservationIgnored var isBackingUp = false

    private let refreshActor = RefreshActor()

    init() {
        setupCloudKitListener()
    }

    var enableIcloudSync: Bool {
        UserDefaults.standard.bool(forKey: Const.enableIcloudSync)
    }

    var autoRefreshIgnoresSync: Bool {
        UserDefaults.standard.bool(forKey: Const.autoRefreshIgnoresSync)
    }

    /// Writing feeds or merging duplicates while an import is only half applied resolves against a
    /// state that isn't the one the other device sent — a removal still in flight loses to the
    /// local entry. Capped so a sync that never reports itself done can't starve either forever.
    var shouldDeferForSync: Bool {
        guard isSyncingIcloud, !autoRefreshIgnoresSync else {
            return false
        }
        guard let syncStartedAt else {
            return true
        }
        return syncStartedAt.timeIntervalSinceNow > -Const.maxSyncRefreshDeferSeconds
    }

    func clearSyncState() {
        isSyncingIcloud = false
        syncStartedAt = nil
    }

    func consumeTriggerPasteAction() -> Bool {
        if triggerPasteAction {
            triggerPasteAction = false
            return true
        }
        return false
    }

    func consumeTriggerPasteAndQueueAction() -> Bool {
        if triggerPasteAndQueueAction {
            triggerPasteAndQueueAction = false
            return true
        }
        return false
    }

    func consumeTriggerSearchYoutube() -> Bool {
        if triggerSearchYoutube {
            triggerSearchYoutube = false
            return true
        }
        return false
    }

    func refreshAll(
        hardRefresh: Bool = false,
        source: RefreshSource = .manual
    ) async {
        await refresh(hardRefresh: hardRefresh, source: source)
    }

    /// `ignoreCache` is for a refresh the user asked for on one subscription: a cached feed would
    /// answer it with the bytes they already have (see `VideoCrawler.fetchFeedData`).
    func refreshSubscription(
        subscriptionId: PersistentIdentifier,
        hardRefresh: Bool = false,
        ignoreCache: Bool = false
    ) async {
        await refresh(subscriptionIds: [subscriptionId], hardRefresh: hardRefresh, ignoreCache: ignoreCache)
    }

    func startLoading() async -> Bool {
        let canStartLoading = await refreshActor.startLoading()
        if canStartLoading {
            isLoading = true
        }
        return canStartLoading
    }

    func stopLoading() async {
        await refreshActor.stopLoading()
        isLoading = false
    }

    private func refresh(
        subscriptionIds: [PersistentIdentifier]? = nil,
        hardRefresh: Bool = false,
        ignoreCache: Bool = false,
        source: RefreshSource = .manual
    ) async {
        guard source == .manual || !shouldDeferForSync else {
            Log.info("refresh deferred, iCloud sync in progress")
            return
        }

        let canStartLoading = await startLoading()
        guard canStartLoading else {
            Log.info("currently refreshing, stopping now")
            return
        }

        await performRefresh(
            subscriptionIds: subscriptionIds,
            hardRefresh: hardRefresh,
            ignoreCache: ignoreCache
        )
        await stopLoading()
    }

    private func performRefresh(
        subscriptionIds: [PersistentIdentifier]?,
        hardRefresh: Bool,
        ignoreCache: Bool = false
    ) async {
        let isFullRefresh = subscriptionIds?.isEmpty ?? true
        if isFullRefresh {
            UserDefaults.standard.set(Date(), forKey: Const.lastAutoRefreshDate)
        }
        do {
            let task = VideoService.loadNewVideosInBg(
                subscriptionIds: subscriptionIds,
                fetchDurations: true,
                ignoreCache: ignoreCache
            )
            let result = try await task.value
            if isFullRefresh {
                failedSubscriptionsCount = result.failedSubscriptionsCount
                totalSubscriptionsCount = result.totalSubscriptionsCount
            }
        } catch {
            Log.info("Error during refresh: \(error)")
            if isFullRefresh {
                // couldn't even get as far as fetching individual feeds — treat as a total failure
                failedSubscriptionsCount = 1
                totalSubscriptionsCount = 1
            }
        }
        await cleanup(hardRefresh: hardRefresh)
        PodcastDownloadManager.shared.scheduleSync()
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
        Log.info("Background task running now")
        scheduleVideoRefresh()

        NotificationManager.notifyRun(.setup)

        let canStartLoading = await startLoading()
        guard canStartLoading else {
            Log.info("Already refreshing")
            NotificationManager.notifyRun(.abort)
            return
        }

        do {
            NotificationManager.notifyRun(.start)

            let task = VideoService.loadNewVideosInBg(fetchDurations: false)
            // batch fetch durations only when necessary, e.g. when opening the app
            UserDefaults.standard.set(true, forKey: Const.requiresDurationFetch)

            let newVideos = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
            UserDefaults.standard.set(Date(), forKey: Const.lastAutoRefreshDate)
            if newVideos.videoCount > 0 {
                Log.info("notifyNewVideos")
                await NotificationManager.notifyNewVideos(newVideos)
            }
            NotificationManager.notifyRun(.end)
        } catch {
            Log.error("Error during background refresh: \(error)")
            Signal.error("backgroundRefreshFailed")
            NotificationManager.notifyRun(.error, error.localizedDescription)
        }

        await stopLoading()
        NotificationManager.notifyRun(.stopLoading)
        #endif
    }
}
