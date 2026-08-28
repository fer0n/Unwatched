//
//  TranscriptView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct TranscriptView: View {
    @Environment(PlayerManager.self) var player

    let video: Video
    let transcriptUrl: String?
    let youtubeId: String

    @Binding var viewModel: ViewModel
    let scrollProxy: ScrollViewProxy

    @State private var autoScroll = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                searchBar
                if viewModel.transcript?.isEmpty != false {
                    Text(transcriptStatus)
                        .italic()
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        Section {
                            TranscriptList(
                                transcript: viewModel.filteredTranscript,
                                activeTime: activeTime,
                                isCurrentVideo: isCurrentVideo,
                                isSearching: !viewModel.text.debounced.isEmpty
                            )
                        } header: {
                            followTranscriptButton
                                .padding(.vertical)
                        }
                    }
                    .background {
                        ScrollViewInteractionDetector {
                            autoScroll = false
                        }
                    }
                    .onChange(of: activeEntryId) { _, _ in
                        if autoScroll, let id = scrollTargetId {
                            withAnimation {
                                scrollProxy.scrollTo(id, anchor: .top)
                            }
                        }
                    }
                }

                Spacer()
                    .frame(height: 300)
                    .task(id: refreshId) {
                        await viewModel.handleTranscriptLoading(
                            video,
                            transcriptUrl
                        )
                    }
            }
        }
    }

    var searchBar: some View {
        HStack {
            TranscriptSearch(text: $viewModel.text)
                .padding(.leading, 10)

            TranscriptFieldClearButton(text: $viewModel.text)
                .foregroundStyle(.gray)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        #if os(iOS)
        .background(Capsule().fill(Color.insetBackgroundColor))
        #endif
    }

    @ViewBuilder
    var followTranscriptButton: some View {
        if viewModel.transcript?.isEmpty == false && isCurrentVideo {
            Button {
                autoScroll = true
                if let id = scrollTargetId {
                    withAnimation {
                        scrollProxy.scrollTo(id, anchor: .top)
                    }
                }
            } label: {
                Label("scrollToNow", systemImage: "location.fill")
            }
            .buttonBorderShape(.capsule)
            .foregroundStyle(Color.automaticBlack)
            #if !os(visionOS)
            .tint(Color.insetBackgroundColor)
            #endif
            .buttonStyle(.borderedProminent)
            .opacity(autoScroll ? 0 : 1)
            .animation(.default, value: autoScroll)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    var transcriptStatus: LocalizedStringKey {
        if viewModel.isLoading {
            return "loadingTranscript"
        }
        if video.isPodcast {
            return "noTranscriptYet"
        }
        if isCurrentVideo {
            if player.transcriptUrl == "" {
                return "transcriptUnavailable"
            }
        }
        if viewModel.transcript == nil {
            return "startToLoadTranscript"
        }
        // empty transcript means unavailable
        return "transcriptUnavailable"
    }

    var activeTime: Double {
        (player.currentTime ?? 0) + 1
    }

    var activeEntryId: UUID? {
        guard isCurrentVideo, let transcript = viewModel.transcript else { return nil }
        let time = activeTime
        return transcript.first(where: {
            $0.start < time && ($0.start + $0.duration) >= time
        })?.id
    }

    var scrollTargetId: UUID? {
        guard isCurrentVideo, let transcript = viewModel.transcript else { return nil }
        let time = activeTime
        guard let activeIndex = transcript.firstIndex(where: {
            $0.start < time && ($0.start + $0.duration) >= time
        }) else { return nil }

        let targetIndex = max(0, activeIndex - 3)
        return transcript[targetIndex].id
    }

    var refreshId: String {
        youtubeId + (transcriptUrl ?? "empty")
    }

    var isCurrentVideo: Bool {
        player.video?.youtubeId == youtubeId
    }
}

extension TranscriptView {
    @Observable class ViewModel {
        var transcript: [TranscriptEntry]? {
            didSet { transcriptVersion += 1 }
        }
        var text = DebouncedText()
        var isLoading = false
        var isGenerating = false
        var generationProgress: Double = 0
        var generationError: String?

        /// Set once the sweep has reached the end, so the button can dissolve the fill before it's swapped out.
        var isFadingOutProgress = false

        @ObservationIgnored
        private var generationTask: Task<Void, Never>?

        /// Held separately: the transcription runs detached, so cancelling the task that awaits it would otherwise
        /// leave it transcribing the whole episode with nobody listening.
        @ObservationIgnored
        private var transcriptionTask: Task<[TranscriptEntry], Error>?

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

            if let cache, cache.version == transcriptVersion, cache.searchText == searchText {
                return cache.items
            }
            let items = makeFilteredTranscript(transcript, searchText)
            cache = FilterCache(version: transcriptVersion, searchText: searchText, items: items)
            return items
        }

        private func makeFilteredTranscript(
            _ transcript: [TranscriptEntry]?,
            _ searchText: String
        ) -> [TranscriptDisplayItem] {
            guard let transcript = transcript else { return [] }

            if searchText.isEmpty {
                return transcript.map { .entry($0, isMatch: false) }
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

        @MainActor
        func generateTranscript(for video: Video) {
            guard !isGenerating else { return }
            isGenerating = true
            generationProgress = 0
            isFadingOutProgress = false
            generationError = nil

            let youtubeId = video.youtubeId
            let task = TranscriptService.generateTranscript(for: video) { fraction in
                Task { @MainActor [weak self] in
                    self?.generationProgress = fraction
                }
            }
            transcriptionTask = task

            generationTask = Task { [weak self] in
                defer {
                    self?.isGenerating = false
                    self?.generationTask = nil
                    self?.transcriptionTask = nil
                }
                do {
                    let entries = try await task.value
                    await self?.finishProgress()
                    withAnimation {
                        self?.transcript = entries
                    }
                    self?.transcriptYoutubeId = youtubeId
                } catch is CancellationError {
                    return
                } catch {
                    Log.error("generateTranscript: \(error.localizedDescription)")
                    self?.generationError = error.localizedDescription
                    self?.generationProgress = 0
                }
            }
        }

        /// Runs the sweep out to the end and starts fading it, so the swap that follows reads as one motion.
        @MainActor
        private func finishProgress() async {
            generationProgress = 1
            try? await Task.sleep(for: .seconds(0.25))
            isFadingOutProgress = true
            try? await Task.sleep(for: .seconds(0.15))
        }

        @MainActor
        func cancelGeneration() {
            transcriptionTask?.cancel()
            generationTask?.cancel()
            transcriptionTask = nil
            generationTask = nil
            isGenerating = false
        }

        @MainActor
        func handleTranscriptLoading(
            _ video: Video,
            _ transcriptUrl: String?
        ) async {
            let youtubeId = video.youtubeId
            if youtubeId != transcriptYoutubeId && transcript != nil {
                transcript = nil
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
                transcript = await TranscriptService.podcastTranscript(for: video).value
            } else {
                transcript = try? await TranscriptService.getTranscript(
                    from: transcriptUrl,
                    youtubeId: youtubeId,
                    )
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
