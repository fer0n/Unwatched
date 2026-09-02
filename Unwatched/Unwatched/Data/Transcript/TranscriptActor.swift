//
//  TranscriptActor.swift
//  Unwatched
//

import SwiftData
import UnwatchedShared

@ModelActor actor TranscriptActor {
    func getTranscript(for youtubeId: String) async -> [TranscriptEntry]? {
        await getPayload(for: youtubeId)?.entries
    }

    func getPayload(for youtubeId: String) async -> TranscriptPayload? {
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
        if let payload = try? decoder.decode(TranscriptPayload.self, from: transcript.data) {
            return payload
        }
        // written before the origin was recorded: a bare array of entries
        guard let entries = try? decoder.decode([TranscriptEntry].self, from: transcript.data) else {
            Log.error("Failed to decode transcript data for \(youtubeId)")
            return nil
        }
        return TranscriptPayload(entries: entries, origin: .published)
    }

    func cacheTranscript(
        _ transcript: [TranscriptEntry],
        for youtubeId: String,
        origin: TranscriptOrigin = .published
    ) {
        Log.info("cacheTranscript for \(youtubeId)")
        let encoder = JSONEncoder()
        guard let encoded = try? encoder.encode(TranscriptPayload(entries: transcript, origin: origin)) else {
            Log.warning("Failed to encode transcript for caching")
            return
        }

        // A generated transcript replaces whatever is cached — including the empty entry that
        // stands for "this video has no transcript", which is what a podcast episode starts out
        // with once its description tab has been opened.
        let existing = FetchDescriptor<Transcript>(
            predicate: #Predicate<Transcript> { $0.youtubeId == youtubeId }
        )
        for transcript in (try? modelContext.fetch(existing)) ?? [] {
            modelContext.delete(transcript)
        }

        let transcriptCache = Transcript(youtubeId, data: encoded)
        modelContext.insert(transcriptCache)
        try? modelContext.save()
    }
}
