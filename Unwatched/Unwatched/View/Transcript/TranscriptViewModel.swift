//
//  TranscriptViewModel.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

extension TranscriptView {
    @Observable class ViewModel: ProgressSweeping {
        var transcript: [TranscriptEntry]? {
            didSet { transcriptVersion += 1 }
        }
        var text = DebouncedText()
        var isLoading = false
        var isGenerating = false
        var isRestoring = false
        var isAligning = false

        /// Set when a check found the published transcript out of sync, so the view can offer to
        /// correct it without having done so behind the user's back.
        var driftDetected = false

        /// Where the loaded transcript came from; `nil` while none is loaded.
        var origin: TranscriptOrigin?

        /// How the loaded transcript relates to the audio, once it's been checked.
        var alignment: TranscriptAlignment? {
            didSet { transcriptVersion += 1 }
        }

        var sweepProgress: Double = 0
        var generationError: String?

        var isFadingOutProgress = false

        @ObservationIgnored
        var transcriptYoutubeId: String = ""

        @ObservationIgnored
        private var transcriptVersion = 0

        @ObservationIgnored
        private var cache: FilterCache?

        var filteredTranscript: [TranscriptDisplayItem] {
            // Read both before the cache check so this stays observed even when returning the cache.
            let transcript = transcript
            let searchText = text.debounced
            let gaps = alignment?.gaps ?? []

            if let cache, cache.version == transcriptVersion, cache.searchText == searchText {
                return cache.items
            }
            let items = makeFilteredTranscript(transcript, searchText, gaps)
            cache = FilterCache(version: transcriptVersion, searchText: searchText, items: items)
            return items
        }

        private func makeFilteredTranscript(
            _ transcript: [TranscriptEntry]?,
            _ searchText: String,
            _ gaps: [TranscriptAlignment.Gap]
        ) -> [TranscriptDisplayItem] {
            guard let transcript = transcript else { return [] }

            if searchText.isEmpty {
                return Self.interleaving(gaps, into: transcript)
            }

            var result: [TranscriptDisplayItem] = []

            let matchIndices = transcript.indices.filter { index in
                transcript[index].text.localizedCaseInsensitiveContains(searchText)
            }

            if matchIndices.isEmpty { return [] }

            var lastIncludedIndex = -1

            for index in matchIndices {
                let start = max(0, index - 1)
                let end = min(transcript.count - 1, index + 1)

                if start > lastIncludedIndex + 1 {
                    result.append(.separator(UUID()))
                }

                for innerIndex in start...end where innerIndex > lastIncludedIndex {
                    let entry = transcript[innerIndex]
                    let isMatch = entry.text.localizedCaseInsensitiveContains(searchText)
                    result.append(.entry(entry, isMatch: isMatch))
                    lastIncludedIndex = innerIndex
                }
            }

            return result
        }

        /// Starts generating a transcript for `video` — or, if one is already running (kicked off from a
        /// Shortcut, say), just lets `watchGeneration` pick it up.
        @MainActor
        func generateTranscript(for video: Video, force: Bool = false) {
            isGenerating = true
            sweepProgress = 0
            isFadingOutProgress = false
            generationError = nil
            TranscriptService.GenerationCoordinator.shared.generate(for: video, force: force)
        }

        /// Places each gap between the entries it falls between, so the break in coverage is
        /// visible where it happens.
        static func interleaving(
            _ gaps: [TranscriptAlignment.Gap],
            into transcript: [TranscriptEntry]
        ) -> [TranscriptDisplayItem] {
            guard !gaps.isEmpty else {
                return transcript.map { .entry($0, isMatch: false) }
            }
            var remaining = gaps.sorted { $0.audioStart < $1.audioStart }
            var items = [TranscriptDisplayItem]()
            for entry in transcript {
                while let next = remaining.first, next.audioStart <= entry.start {
                    items.append(.gap(next, id: UUID()))
                    remaining.removeFirst()
                }
                items.append(.entry(entry, isMatch: false))
            }
            items.append(contentsOf: remaining.map { .gap($0, id: UUID()) })
            return items
        }

        /// Corrects the published transcript's timings against the audio that actually plays.
        @MainActor
        func alignTranscript(for video: Video) {
            guard !isAligning else { return }
            // withAnimation, not .animation(value:) on the banner: the modifier sits on a
            // conditional that isn't there to carry it while the banner is hidden, so it never
            // animates the insertion
            withAnimation { isAligning = true }
            generationError = nil
            sweepProgress = 0
            isFadingOutProgress = false
            Task { [self] in
                defer { withAnimation { isAligning = false } }
                do {
                    let payload = try await TranscriptService.alignTranscript(for: video) { fraction in
                        Task { @MainActor in
                            self.sweepProgress = fraction
                        }
                    }.value
                    await finishProgress()
                    withAnimation {
                        transcript = payload.entries
                        alignment = payload.alignment
                    }
                    origin = payload.origin
                    withAnimation { driftDetected = false }
                    transcriptYoutubeId = video.youtubeId

                    if let alignment = payload.alignment {
                        await GapChapterService.insertGapChapters(
                            for: video,
                            alignment: alignment,
                            transcript: payload.entries
                        )
                    }
                } catch {
                    generationError = error.localizedDescription
                    cancelProgress()
                }
            }
        }

        /// Checks a published transcript against the audio, but only when that costs nothing the
        /// user would have to agree to - no model download, and the episode already downloaded.
        @MainActor
        func checkAlignmentIfCheap(for video: Video) async {
            guard origin == .published, alignment == nil, transcript?.isEmpty == false,
                  !isAligning, !isGenerating else { return }
            guard let drifted = await TranscriptService.detectTranscriptDrift(for: video).value,
                  transcriptYoutubeId == video.youtubeId else { return }
            if drifted {
                withAnimation { driftDetected = true }
            } else {
                alignment = .identity
            }
        }

        /// Puts the show's own transcript back over a generated one, re-read from the feed.
        @MainActor
        func restorePublishedTranscript(for video: Video) {
            guard !isRestoring else { return }
            isRestoring = true
            generationError = nil
            Task {
                defer { isRestoring = false }
                do {
                    let entries = try await TranscriptService.restorePublishedTranscript(for: video).value
                    withAnimation {
                        transcript = entries
                    }
                    origin = .published
                    alignment = nil
                    driftDetected = false
                    transcriptYoutubeId = video.youtubeId
                } catch {
                    generationError = error.localizedDescription
                }
            }
        }

        @MainActor
        func syncGeneration(for youtubeId: String) {
            let coordinator = TranscriptService.GenerationCoordinator.shared
            if coordinator.youtubeId == youtubeId {
                if coordinator.isGenerating && !isGenerating {
                    isFadingOutProgress = false
                }
                isGenerating = coordinator.isGenerating
                sweepProgress = coordinator.progress
                generationError = coordinator.error
            } else if isGenerating {
                isGenerating = false
                sweepProgress = 0
                generationError = nil
            }
        }

        /// Mirrors the shared coordinator's state for `video` for as long as this task runs, so this
        /// screen reflects a generation regardless of who started it, and loads the result once it lands.
        @MainActor
        func watchGeneration(for video: Video) async {
            let coordinator = TranscriptService.GenerationCoordinator.shared
            let youtubeId = video.youtubeId
            var handledFinishedVersion = coordinator.finishedYoutubeId == youtubeId ? coordinator.finishedVersion : -1

            while true {
                syncGeneration(for: youtubeId)

                if coordinator.finishedYoutubeId == youtubeId && coordinator.finishedVersion != handledFinishedVersion {
                    handledFinishedVersion = coordinator.finishedVersion
                    if coordinator.error == nil {
                        await finishProgress()
                        let payload = await TranscriptService.podcastTranscriptPayload(for: video).value
                        withAnimation {
                            transcript = payload.entries
                        }
                        origin = payload.origin
                        alignment = payload.alignment
                        transcriptYoutubeId = youtubeId
                    }
                }

                do {
                    try await Task.sleep(for: .milliseconds(150))
                } catch {
                    return
                }
            }
        }

        @MainActor
        func handleTranscriptLoading(
            _ video: Video,
            _ transcriptUrl: String?
        ) async {
            let youtubeId = video.youtubeId
            if youtubeId != transcriptYoutubeId && transcript != nil {
                transcript = nil
                origin = nil
                alignment = nil
                driftDetected = false
            }
            guard transcript == nil else {
                Log.info("Transcript already loaded for \(youtubeId)")
                return
            }

            isLoading = true
            defer { isLoading = false }

            if video.isPodcast {
                // an episode has no captions to fetch, but it may have one it was given earlier or one the show
                // publishes itself
                let payload = await TranscriptService.podcastTranscriptPayload(for: video).value
                transcript = payload.entries
                origin = payload.origin
                alignment = payload.alignment
            } else {
                transcript = try? await TranscriptService.getTranscript(
                    from: transcriptUrl,
                    youtubeId: youtubeId,
                    )
                origin = .published
            }
            Log.info("Transcript loaded for \(youtubeId): \(transcript?.count ?? 0) entries")
            transcriptYoutubeId = youtubeId
        }
    }
}

private struct FilterCache {
    let version: Int
    let searchText: String
    let items: [TranscriptDisplayItem]
}
