//
//  ChapterAutomation.swift
//  Unwatched
//

import Foundation
import SwiftData
import UnwatchedShared

@MainActor
enum ChapterAutomation {
    static var hasPendingWork = false
    static var isOnExternalPower = false
    static var skippedIds = Set<String>()
    private static var currentRun: Task<Void, Never>?
    private static var isRunRequested = false
    private static var isChargingRunRequested = false
    private static var scheduledRun: Task<Void, Never>?

    static var isAutomationEnabled: Bool {
        UserDefaults.standard.bool(forKey: Const.chapterShortcutAutomation)
    }

    static var canTranscribe: Bool {
        CloudKeyValueStore.hasPremium && TranscriptService.canGenerateTranscript
    }

    static var mode: ChapterGenerationMode {
        guard CloudKeyValueStore.hasPremium else { return .off }
        return UserDefaults.standard.string(forKey: Const.chapterGenerationMode)
            .flatMap(ChapterGenerationMode.init) ?? .off
    }

    static func needsChapters(_ video: Video) -> Bool {
        needsChapters(video, mode: mode)
    }

    static func needsChapters(_ video: Video, mode: ChapterGenerationMode) -> Bool {
        guard mode != .off, video.chapterGenerationDate == nil else { return false }
        if let override = video.subscription?.chapterGeneration {
            return override
        }
        switch mode {
        case .all: return true
        case .withoutChapters: return ownChapterCount(video) == 0
        case .selectedChannels, .off: return false
        }
    }

    static func ownChapterCount(_ video: Video) -> Int {
        video.ownChapterData.count(where: isOwnChapter)
    }

    private static func isOwnChapter(_ chapter: SendableChapter) -> Bool {
        (chapter.category == nil || chapter.category == .chapter) && !chapter.isIntro && !chapter.isOutro
    }

    private static func scope(_ key: String) -> ChapterAutomationScope {
        guard CloudKeyValueStore.hasPremium, isAutomationEnabled else { return .off }
        return UserDefaults.standard.string(forKey: key).flatMap(ChapterAutomationScope.init) ?? .off
    }

    private static var podcastScope: ChapterAutomationScope { scope(Const.chapterAutomationPodcasts) }
    private static var videoScope: ChapterAutomationScope { scope(Const.chapterAutomationVideos) }

    private static var isActive: Bool {
        mode != .off && (canTranscribe || podcastScope != .off || videoScope != .off)
    }

    static func setup() {
        #if os(iOS)
        registerBackgroundTask()
        #endif
        scheduleRun(on: .NSProcessInfoPowerStateDidChange)
        scheduleRun(on: ModelContext.didSave, if: changesQueue)
        scheduleRunOnTranscriptUrlChange()
    }

    static func scheduleRun() {
        ChapterAutomationStatus.shared.refresh()
        guard isActive else { return }
        scheduledRun?.cancel()
        scheduledRun = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await runNow().value
        }
    }

    private static func scheduleRun(
        on name: Notification.Name,
        if condition: @escaping @Sendable (Notification) -> Bool = { _ in true }
    ) {
        NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { notification in
            guard condition(notification) else { return }
            Task { @MainActor in
                scheduleRun()
            }
        }
    }

    private static func scheduleRunOnTranscriptUrlChange() {
        withObservationTracking {
            _ = PlayerManager.shared.transcriptUrl
        } onChange: {
            Task { @MainActor in
                scheduleRun()
                scheduleRunOnTranscriptUrlChange()
            }
        }
    }

    private nonisolated static func changesQueue(_ notification: Notification) -> Bool {
        let keys: [ModelContext.NotificationKey] = [.insertedIdentifiers, .updatedIdentifiers, .deletedIdentifiers]
        return keys.contains { key in
            let ids = notification.userInfo?[key.rawValue] as? [PersistentIdentifier] ?? []
            return ids.contains { $0.entityName == "QueueEntry" }
        }
    }

    @discardableResult
    static func runNow(whileCharging: Bool = false) -> Task<Void, Never> {
        if whileCharging {
            isChargingRunRequested = true
        }
        if let currentRun {
            isRunRequested = true
            return currentRun
        }
        let task = Task {
            repeat {
                let whileCharging = isChargingRunRequested
                isRunRequested = false
                isChargingRunRequested = false
                await run(whileCharging: whileCharging)
            } while isRunRequested
            currentRun = nil
            #if os(iOS)
            updateBackgroundTask()
            #endif
        }
        currentRun = task
        return task
    }

    private static func run(whileCharging: Bool) async {
        hasPendingWork = false
        isOnExternalPower = whileCharging
        if mode == .withoutChapters {
            await fetchUpcomingPodcastChapters()
        }
        if canTranscribe {
            await transcribeUpcoming(whileCharging: whileCharging)
        }
        for videoId in automationCandidates() {
            await notifyWhenReady(videoId)
        }
    }

    static func upcomingVideos() -> [Video] {
        let current = PlayerManager.shared.video
        let queued = QueueFilter.all.videos(DataProvider.mainContext)
            .filter { $0.youtubeId != current?.youtubeId }
        return [current].compactMap { $0 } + queued
    }

    private static func automationCandidates() -> [PersistentIdentifier] {
        let podcastCount = podcastScope.itemCount
        let videoCount = videoScope.itemCount
        return upcomingVideos()
            .prefix(max(podcastCount, videoCount))
            .enumerated()
            .filter { index, video in
                video.watchedDate == nil
                    && needsChapters(video)
                    && index < (video.isPodcast ? podcastCount : videoCount)
            }
            .map(\.element.persistentModelID)
    }

    private static func notifyWhenReady(_ videoId: PersistentIdentifier) async {
        guard let video: Video = DataProvider.mainContext.existingModel(for: videoId),
              video.chapterGenerationDate == nil else {
            return
        }
        if video.isPodcast, await isAwaitingTranscript(video) {
            return
        }
        guard (try? await loadTranscript(video)) != nil else { return }
        await sendNotification(for: video)
    }
}
