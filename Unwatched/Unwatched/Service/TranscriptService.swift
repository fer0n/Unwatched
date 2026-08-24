//
//  TranscriptService.swift
//  Unwatched
//

import Foundation
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

    static func analyseBreaks(_ transcripts: [TranscriptEntry]) -> [TranscriptEntry] {
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

    // MARK: - Generating

    /// The transcript an episode already has: one that's been generated before, or the one the show publishes itself.
    @MainActor
    static func podcastTranscript(for video: Video) -> Task<[TranscriptEntry], Never> {
        let youtubeId = video.youtubeId
        let feedUrl = video.subscription?.link
        let cacheContainer = DataProvider.shared.localCacheContainer

        return Task.detached {
            let repo = TranscriptActor(modelContainer: cacheContainer)
            if let cached = await repo.getTranscript(for: youtubeId) {
                return cached
            }
            guard let feedUrl else { return [] }

            switch await PodcastService.fetchTranscript(feedUrl: feedUrl, episodeId: youtubeId).lookup {
            case .found(let entries):
                let cleaned = analyseBreaks(entries)
                await repo.cacheTranscript(cleaned, for: youtubeId)
                return cleaned
            case .notPublished:
                // remembered, so opening the tab again doesn't re-read the feed.
                await repo.cacheTranscript([], for: youtubeId)
                return []
            case .unreachable:
                return []
            }
        }
    }

    /// Whether a transcript can be produced for an episode that doesn't have one yet.
    static var canGenerateTranscript: Bool {
        #if os(tvOS)
        return false
        #else
        return SpeechTranscriptService.isSupported
        #endif
    }

    /// Produces a transcript for a podcast episode and caches it, after which it loads like any other transcript.
    @MainActor
    static func generateTranscript(
        for video: Video,
        progress: @escaping @Sendable (_ fraction: Double) -> Void
    ) -> Task<[TranscriptEntry], Error> {
        let youtubeId = video.youtubeId
        let mediaUrl = video.mediaUrl
        let feedUrl = video.subscription?.link
        let isDownloaded = video.downloadedDate != nil
        let cacheContainer = DataProvider.shared.localCacheContainer

        return Task.detached {
            let repo = TranscriptActor(modelContainer: cacheContainer)

            // the feed gets one more look: it's cheap next to transcribing, and a show that published a transcript
            // since the tab was last opened is worth catching. The same read supplies the show's language, which
            // is what the episode has to be transcribed in.
            var feed: PodcastTranscriptLookupResult?
            if let feedUrl {
                feed = await PodcastService.fetchTranscript(feedUrl: feedUrl, episodeId: youtubeId)
            }
            if case .found(let published) = feed?.lookup {
                Log.info("using the feed's own transcript for \(youtubeId)")
                let cleaned = analyseBreaks(published)
                await repo.cacheTranscript(cleaned, for: youtubeId)
                return cleaned
            }

            #if os(tvOS)
            throw TranscriptError.noUrl
            #else
            progress(0.02)
            let (fileUrl, isTemporary) = try await audioFile(youtubeId: youtubeId, mediaUrl: mediaUrl,
                                                             isDownloaded: isDownloaded)
            defer {
                if isTemporary {
                    try? FileManager.default.removeItem(at: fileUrl)
                }
            }

            let entries = try await SpeechTranscriptService.transcribe(
                fileUrl: fileUrl,
                language: feed?.language
            ) { fraction in
                // the leading slice covers fetching the audio and installing the speech model, neither of which
                // reports progress of its own
                progress(0.1 + fraction * 0.9)
            }
            let cleaned = analyseBreaks(entries)
            await repo.cacheTranscript(cleaned, for: youtubeId)
            return cleaned
            #endif
        }
    }

    #if !os(tvOS)
    /// The episode as a local file, which is what `SpeechAnalyzer` reads.
    private static func audioFile(
        youtubeId: String,
        mediaUrl: URL?,
        isDownloaded: Bool
    ) async throws -> (url: URL, isTemporary: Bool) {
        if isDownloaded, let downloaded = PodcastDownloadStore.downloadedFile(for: youtubeId) {
            return (downloaded, false)
        }
        guard let mediaUrl else {
            throw TranscriptError.noAudio
        }
        Log.info("downloading \(youtubeId) to transcribe it")
        let (temporary, response) = try await URLSession.shared.download(from: mediaUrl)
        guard response.isSuccessfulHttp else {
            try? FileManager.default.removeItem(at: temporary)
            throw TranscriptError.noAudio
        }
        // the downloaded file has no extension, and AVAudioFile needs one to pick a reader
        let fileExtension = mediaUrl.pathExtension.isEmpty ? "mp3" : mediaUrl.pathExtension
        let destination = temporary.appendingPathExtension(fileExtension)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temporary, to: destination)
        return (destination, true)
    }
    #endif

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
            if transript.isEmpty {
                throw TranscriptError.emptyTranscript
            }
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
            ChapterService.insertChapters(chapters, for: video)
        }
    }
}
