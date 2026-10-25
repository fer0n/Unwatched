//
//  ChapterAutomation+TranscriptRepair.swift
//  Unwatched
//

import Foundation
import UnwatchedShared

extension ChapterAutomation {
    enum DriftCheck {
        case unavailable, inSync, realigned
    }

    static func loadTranscript(_ video: Video, repair: Bool = false) async throws {
        let entries = video.isPodcast
            ? try await podcastEntries(video, repair: repair)
            : try await TranscriptService.getTranscript(from: transcriptUrl(video), youtubeId: video.youtubeId)
        if entries.isEmpty {
            throw TranscriptError.emptyTranscript
        }
    }

    static func needsAlignmentCheck(_ payload: TranscriptPayload) -> Bool {
        payload.origin == .published && payload.alignment == nil
    }

    @discardableResult
    static func alignTranscriptIfDrifted(_ video: Video) async throws -> DriftCheck {
        guard let drifted = await TranscriptService.detectTranscriptDrift(for: video).value else {
            return .unavailable
        }
        guard drifted else { return .inSync }
        Log.chapters.info("ChapterAutomation: aligning \(video.youtubeId)")
        let aligned = try await TranscriptService.alignTranscript(for: video) { _ in }.value
        if let alignment = aligned.alignment {
            await GapChapterService.insertGapChapters(for: video, alignment: alignment, transcript: aligned.entries)
        }
        return .realigned
    }

    private static func podcastEntries(_ video: Video, repair: Bool) async throws -> [TranscriptEntry] {
        let payload = await TranscriptService.podcastTranscriptPayload(for: video).value
        guard repair else { return payload.entries }
        if payload.entries.isEmpty && TranscriptService.canGenerateTranscript {
            Log.chapters.info("ChapterAutomation: generating the missing transcript for \(video.youtubeId)")
            return try await TranscriptService.GenerationCoordinator.shared.generate(for: video).value
        }
        if needsAlignmentCheck(payload) {
            try await alignTranscriptIfDrifted(video)
        }
        return payload.entries
    }

    private static func transcriptUrl(_ video: Video) -> String? {
        let player = PlayerManager.shared
        return player.video?.youtubeId == video.youtubeId ? player.transcriptUrl : nil
    }
}
