//
//  TranscriptService.swift
//  Unwatched
//

import UnwatchedShared
import SwiftData

struct TranscriptService {
    static func getTranscript(from url: String?, youtubeId: String) async -> [TranscriptEntry]? {
        Log.info("getTranscript from \(url ?? "–") for \(youtubeId)")
        let imageContainer = DataProvider.shared.localCacheContainer
        let task: Task<[TranscriptEntry]?, Error> = Task.detached {
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
            return nil
        }
        guard let transcriptEntries = try? await task.value else {
            Log.error("Failed to load transcript from \(url ?? "–")")
            return nil
        }
        return transcriptEntries
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
}
