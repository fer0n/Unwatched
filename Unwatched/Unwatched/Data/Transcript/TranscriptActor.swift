//
//  TranscriptActor.swift
//  Unwatched
//

import SwiftData
import UnwatchedShared

@ModelActor actor TranscriptActor {
    func getTranscript(for youtubeId: String) async -> [TranscriptEntry]? {
        var fetch = FetchDescriptor<Transcript>(
            predicate: #Predicate<Transcript> { $0.youtubeId == youtubeId }
        )
        fetch.fetchLimit = 1
        guard let transcript = (try? modelContext.fetch(fetch))?.first else {
            Log.error("Transcript not found for \(youtubeId)")
            return nil
        }
        Log.info("Transcript found for \(youtubeId)")
        let decoder = JSONDecoder()
        guard let transcriptEntries = try? decoder.decode([TranscriptEntry].self, from: transcript.data) else {
            Log.error("Failed to decode transcript data for \(youtubeId)")
            return nil
        }
        return transcriptEntries
    }

    func cacheTranscript(_ transcript: [TranscriptEntry], for youtubeId: String) {
        Log.info("cacheTranscript for \(youtubeId)")
        let encoder = JSONEncoder()
        guard let encoded = try? encoder.encode(transcript) else {
            Log.warning("Failed to encode transcript for caching")
            return
        }

        let transcriptCache = Transcript(youtubeId, data: encoded)
        modelContext.insert(transcriptCache)
        try? modelContext.save()
    }
}
