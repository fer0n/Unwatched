//
//  TranscriptService.swift
//  Unwatched
//

import UnwatchedShared
import SwiftData

struct TranscriptService {
    static func getTranscript(from url: String?, youtubeId: String) async throws -> [TranscriptEntry] {
        Log.info("getTranscript from \(url ?? "–") for \(youtubeId)")
        let imageContainer = DataProvider.shared.localCacheContainer
        let task: Task<[TranscriptEntry], Error> = Task.detached {
            let repo = TranscriptActor(modelContainer: imageContainer)
            if let cache = await repo.getTranscript(for: youtubeId) {
                return cache
            }

            if url == "" {
                Log.info("Transcript is unavailable for \(youtubeId)")
                await repo.cacheTranscript([], for: youtubeId)
                return []
            }
            if let url, let url = URL(string: url) {
                let loaded = try await loadTranscript(from: url)
                await repo.cacheTranscript(loaded, for: youtubeId)
                return loaded
            }
            throw TranscriptError.noUrl
        }
        return try await task.value
    }

    private static func loadTranscript(from url: URL) async throws -> [TranscriptEntry] {
        Log.info("loadTranscript: \(url)")
        let (data, _) = try await URLSession.shared.data(from: url)
        let parser = TranscriptParser()
        let transcripts = try parser.parse(data: data)
        return analyseBreaks(transcripts)
    }

    private static func analyseBreaks(_ transcripts: [TranscriptEntry]) -> [TranscriptEntry] {
        let paragraphPauseThreshold = 0.3
        var updatedTranscripts = transcripts
        guard updatedTranscripts.count > 1 else { return updatedTranscripts }

        for index in 0..<(updatedTranscripts.count - 1) {
            let currentTranscript = updatedTranscripts[index]
            let nextTranscript = updatedTranscripts[index + 1]

            let currentEndTime = currentTranscript.start + currentTranscript.duration
            let pauseDuration = nextTranscript.start - currentEndTime

            if pauseDuration >= paragraphPauseThreshold {
                updatedTranscripts[index].isParagraphEnd = true
            } else {
                updatedTranscripts[index].isParagraphEnd = false
            }
        }

        if !updatedTranscripts.isEmpty {
            updatedTranscripts[updatedTranscripts.count - 1].isParagraphEnd = false
        }
        return updatedTranscripts
    }

    public static func deleteCache() -> Task<(), Error> {
        return Task {
            let localCacheContainer = DataProvider.shared.localCacheContainer
            let context = ModelContext(localCacheContainer)
            let fetch = FetchDescriptor<Transcript>()
            let transcripts = try context.fetch(fetch)
            for transcript in transcripts {
                context.delete(transcript)
            }
            try context.save()
        }
    }

    @available(iOS 26.0, macOS 26.0, *)
    static func generateAiChapters(for video: Video,
                                   transcriptUrl: String?,
                                   progress: @escaping @Sendable (_ fraction: Double) -> Void
    ) -> Task<(), Error> {
        let youtubeId = video.youtubeId
        let videoId = video.persistentModelID
        let duration = video.duration
        let videoTitle = video.title

        let task: Task<[SendableChapter]?, Error> = Task.detached {
            let transript = try await getTranscript(from: transcriptUrl, youtubeId: youtubeId)
            progress(0.2)
            guard let generatedChapters = try await GenerationService.extractChaptersFromTranscripts(
                videoTitle,
                transript
            ) else {
                Log.info("generateAiChapters: no chapters generated")
                return nil
            }

            print("generatedChapters", generatedChapters)
            let cleaned = ChapterService.updateDurationAndEndTime(in: generatedChapters, videoDuration: duration)
            print("cleaned", cleaned)
            return cleaned
        }

        return Task { @MainActor in
            defer { progress(1) }
            guard let chapters = try await task.value else {
                Log.info("generateAiChapters: no chapters")
                return
            }
            progress(0.95)
            print("chapters", chapters)
            let modelContext = DataProvider.mainContext
            let video: Video? = modelContext.existingModel(for: videoId)

            guard let video else {
                Log.info("generateAiChapters: video not found")
                return
            }

            let chapterModels = chapters.map { $0.getChapter }
            for model in chapterModels {
                modelContext.insert(model)
            }
            video.chapters = chapterModels
            try? modelContext.save()
            if video.youtubeId == PlayerManager.shared.video?.youtubeId {
                PlayerManager.shared.video = video
            }
        }
    }
}
