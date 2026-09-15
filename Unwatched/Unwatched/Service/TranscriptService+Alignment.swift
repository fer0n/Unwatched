//
//  TranscriptService+Alignment.swift
//  Unwatched
//

import Foundation
import SwiftData
import UnwatchedShared

extension TranscriptService {
    /// Whether this episode's transcript can be checked against its audio: only a downloaded
    /// episode, because a show that inserts ads does it per request and the file that plays is
    /// the only one whose timings mean anything.
    @MainActor
    static func canAlignTranscript(for video: Video) -> Bool {
        #if os(tvOS)
        return false
        #else
        guard video.isPodcast, SpeechTranscriptService.isSupported else { return false }
        return PodcastDownloadStore.downloadedFile(for: video.youtubeId) != nil
        #endif
    }

    /// Cheap check for whether the published transcript lines up with the audio, or nil when it
    /// couldn't be checked at all — the episode isn't downloaded, the show's language has no model
    /// on the device yet, or the probes found nothing to go on.
    ///
    /// A transcript that turns out to line up has an identity alignment cached for it, so reopening
    /// the transcript doesn't probe the same episode again.
    @MainActor
    static func detectTranscriptDrift(for video: Video) -> Task<Bool?, Never> {
        let canAlign = canAlignTranscript(for: video)
        let youtubeId = video.youtubeId
        let feedUrl = video.subscription?.link
        let cacheContainer = DataProvider.shared.localCacheContainer

        return Task.detached { () -> Bool? in
            #if os(tvOS)
            return nil
            #else
            guard canAlign, let fileUrl = PodcastDownloadStore.downloadedFile(for: youtubeId) else {
                return nil
            }
            let repo = TranscriptActor(modelContainer: cacheContainer)
            do {
                let source = try await publishedEntries(youtubeId: youtubeId, feedUrl: feedUrl, repo: repo)
                guard await SpeechTranscriptService.isModelInstalled(for: source.language) else {
                    return nil
                }
                let drifted = try await TranscriptAlignmentService.detectDrift(
                    fileUrl: fileUrl,
                    entries: source.entries,
                    language: source.language
                )
                if !drifted {
                    await repo.cachePayload(
                        TranscriptPayload(
                            entries: analyseBreaks(source.entries),
                            origin: .published,
                            alignment: .identity
                        ),
                        for: youtubeId
                    )
                }
                return drifted
            } catch {
                Log.info("alignment check skipped: \(error.localizedDescription)")
                return nil
            }
            #endif
        }
    }

    /// Corrects the published transcript's timings against the audio and caches the result.
    @MainActor
    static func alignTranscript(
        for video: Video,
        progress: @escaping @Sendable (_ fraction: Double) -> Void
    ) -> Task<TranscriptPayload, Error> {
        let youtubeId = video.youtubeId
        let feedUrl = video.subscription?.link
        let cacheContainer = DataProvider.shared.localCacheContainer

        return Task.detached {
            #if os(tvOS)
            throw TranscriptError.noUrl
            #else
            guard let fileUrl = PodcastDownloadStore.downloadedFile(for: youtubeId) else {
                throw TranscriptError.noAudio
            }
            let repo = TranscriptActor(modelContainer: cacheContainer)
            let source = try await publishedEntries(youtubeId: youtubeId, feedUrl: feedUrl, repo: repo)

            let alignment = try await TranscriptAlignmentService.align(
                fileUrl: fileUrl,
                entries: source.entries,
                language: source.language
            ) { fraction in
                progress(fraction * 0.75)
            }

            var entries = alignment.isIdentity
                ? source.entries
                : alignment.applied(to: source.entries)

            // the gaps are the only part of the episode the show didn't transcribe, so filling
            // them in is what makes chapter generation cover the inserted segments too
            let gapEntries = try await TranscriptAlignmentService.transcribeGaps(
                fileUrl: fileUrl,
                alignment: alignment,
                language: source.language
            ) { fraction in
                progress(0.75 + fraction * 0.25)
            }
            if !gapEntries.isEmpty {
                entries = (entries + gapEntries).sorted { $0.start < $1.start }
            }
            entries = analyseBreaks(entries)
            let payload = TranscriptPayload(
                entries: entries,
                origin: alignment.isIdentity ? .published : .aligned,
                alignment: alignment
            )
            await repo.cachePayload(payload, for: youtubeId)
            return payload
            #endif
        }
    }

    /// The show's own transcript, from the cache when it holds an uncorrected one and from the
    /// feed otherwise, along with the language to transcribe probes in.
    private static func publishedEntries(
        youtubeId: String,
        feedUrl: URL?,
        repo: TranscriptActor
    ) async throws -> (entries: [TranscriptEntry], language: String?) {
        guard let feedUrl else { throw TranscriptError.noUrl }
        let lookup = await PodcastService.fetchTranscript(feedUrl: feedUrl, episodeId: youtubeId)
        if case .found(let entries) = lookup.lookup, !entries.isEmpty {
            return (entries, lookup.language)
        }
        guard let cached = await repo.getPayload(for: youtubeId), cached.origin == .published,
              !cached.entries.isEmpty else {
            throw TranscriptError.noPublishedTranscript
        }
        return (cached.entries, lookup.language)
    }
}
