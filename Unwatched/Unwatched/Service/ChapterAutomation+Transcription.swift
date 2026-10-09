//
//  ChapterAutomation+Transcription.swift
//  Unwatched
//

import Foundation
import SwiftData
import UnwatchedShared

extension ChapterAutomation {
    nonisolated static let liveTranscriptions = 2
    static let maxTranscriptionsOptions = [liveTranscriptions, 5, 10, 20]

    private static var maxTranscriptions: Int {
        max(liveTranscriptions, UserDefaults.standard.integer(forKey: Const.maxAutoTranscriptions))
    }

    static func transcribeUpcoming(whileCharging: Bool) async {
        let window = whileCharging ? maxTranscriptions : liveTranscriptions
        for videoId in transcriptionCandidates(upTo: window) {
            await prepareTranscript(videoId)
        }
        if !hasPendingWork {
            hasPendingWork = await containsPendingWork(transcriptionCandidates(upTo: maxTranscriptions, after: window))
        }
    }

    static func fetchUpcomingPodcastChapters() async {
        for video in upcomingVideos().filter(\.isPodcast).prefix(maxTranscriptions) {
            _ = await ChapterService.fetchPodcastChapters(for: video)
        }
    }

    static func isAwaitingTranscript(_ video: Video) async -> Bool {
        guard isTranscribable(video) else { return false }
        return await cachedPayload(video.youtubeId).map(needsSpeechWork) ?? true
    }

    private static func transcriptionCandidates(upTo limit: Int, after skipped: Int = 0) -> [PersistentIdentifier] {
        upcomingVideos()
            .filter { $0.isPodcast && $0.watchedDate == nil }
            .prefix(limit)
            .dropFirst(skipped)
            .filter(isTranscribable)
            .map(\.persistentModelID)
    }

    private static func isTranscribable(_ video: Video) -> Bool {
        canTranscribe
            && video.watchedDate == nil
            && !skippedIds.contains(video.youtubeId)
            && needsChapters(video)
            && PodcastDownloadStore.downloadedFile(for: video.youtubeId) != nil
    }

    private static func containsPendingWork(_ videoIds: [PersistentIdentifier]) async -> Bool {
        for videoId in videoIds {
            guard let video: Video = DataProvider.mainContext.existingModel(for: videoId) else { continue }
            if await isAwaitingTranscript(video) {
                return true
            }
        }
        return false
    }

    private static func needsSpeechWork(_ payload: TranscriptPayload) -> Bool {
        payload.entries.isEmpty || isUnchecked(payload)
    }

    private static func isUnchecked(_ payload: TranscriptPayload) -> Bool {
        payload.origin == .published && payload.alignment == nil
    }

    private static func cachedPayload(_ youtubeId: String) async -> TranscriptPayload? {
        let cacheContainer = DataProvider.shared.localCacheContainer
        return await Task.detached {
            await TranscriptActor(modelContainer: cacheContainer).getPayload(for: youtubeId)
        }.value
    }

    private static func prepareTranscript(_ videoId: PersistentIdentifier) async {
        await waitForOtherGeneration()
        guard let video: Video = DataProvider.mainContext.existingModel(for: videoId),
              isTranscribable(video) else {
            return
        }
        let payload = await TranscriptService.podcastTranscriptPayload(for: video).value
        if payload.entries.isEmpty {
            await transcribe(video)
        } else if isUnchecked(payload) {
            await alignIfDrifted(video)
        }
    }

    private static func waitForOtherGeneration() async {
        while TranscriptService.GenerationCoordinator.shared.isGenerating {
            try? await Task.sleep(for: .seconds(5))
        }
    }

    private static func beginSpeechWork(_ youtubeId: String) -> Bool {
        guard isOnExternalPower || !ProcessInfo.processInfo.isLowPowerModeEnabled else {
            Log.info("ChapterAutomation: Low Power Mode, holding \(youtubeId)")
            hasPendingWork = true
            return false
        }
        #if os(iOS)
        submitBackgroundTask()
        #endif
        return true
    }

    private static func transcribe(_ video: Video) async {
        let youtubeId = video.youtubeId
        guard beginSpeechWork(youtubeId) else { return }
        Log.info("ChapterAutomation: transcribing \(youtubeId)")
        do {
            let entries = try await TranscriptService.GenerationCoordinator.shared.generate(for: video).value
            if entries.isEmpty {
                skippedIds.insert(youtubeId)
            } else {
                ChapterAutomationStatus.shared.transcriptionError = nil
            }
        } catch is CancellationError {
            hasPendingWork = true
        } catch {
            skippedIds.insert(youtubeId)
            ChapterAutomationStatus.shared.transcriptionError = error.localizedDescription
            Log.warning("ChapterAutomation: transcript failed for \(youtubeId): \(error.localizedDescription)")
        }
    }

    private static func alignIfDrifted(_ video: Video) async {
        let youtubeId = video.youtubeId
        guard beginSpeechWork(youtubeId) else { return }
        guard let drifted = await TranscriptService.detectTranscriptDrift(for: video).value else {
            skippedIds.insert(youtubeId)
            return
        }
        guard drifted else { return }
        Log.info("ChapterAutomation: aligning \(youtubeId)")
        do {
            let aligned = try await TranscriptService.alignTranscript(for: video) { _ in }.value
            if let alignment = aligned.alignment {
                await GapChapterService.insertGapChapters(for: video, alignment: alignment, transcript: aligned.entries)
            }
        } catch {
            skippedIds.insert(youtubeId)
            ChapterAutomationStatus.shared.transcriptionError = error.localizedDescription
            Log.warning("ChapterAutomation: alignment failed for \(youtubeId): \(error.localizedDescription)")
        }
    }
}
