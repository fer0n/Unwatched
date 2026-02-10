//
//  TranscriptView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct TranscriptView: View {
    @Environment(PlayerManager.self) var player

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
                            youtubeId,
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

    var activeEntryId: UUID? {
        guard isCurrentVideo, let transcript = viewModel.transcript else { return nil }
        let time = (player.currentTime ?? 0) + 1
        return transcript.first(where: {
            $0.start < time && ($0.start + $0.duration) >= time
        })?.id
    }

    var scrollTargetId: UUID? {
        guard isCurrentVideo, let transcript = viewModel.transcript else { return nil }
        let time = (player.currentTime ?? 0) + 1
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
        var transcript: [TranscriptEntry]?
        var text = DebouncedText()
        var isLoading = false

        @ObservationIgnored
        var transcriptYoutubeId: String = ""

        var filteredTranscript: [TranscriptDisplayItem] {
            guard let transcript = transcript else { return [] }

            if text.debounced.isEmpty {
                return transcript.map { .entry($0, isMatch: false) }
            }

            var result: [TranscriptDisplayItem] = []
            let searchText = text.debounced

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
        func handleTranscriptLoading(
            _ youtubeId: String,
            _ transcriptUrl: String?
        ) async {
            if youtubeId != transcriptYoutubeId && transcript != nil {
                transcript = nil
            }
            guard transcript == nil else {
                Log.info("Transcript already loaded for \(youtubeId)")
                return
            }

            isLoading = true
            defer { isLoading = false }

            transcript = try? await TranscriptService.getTranscript(
                from: transcriptUrl,
                youtubeId: youtubeId,
                )
            Log.info("Transcript loaded for \(youtubeId): \(transcript?.count ?? 0) entries")
            transcriptYoutubeId = youtubeId
        }
    }
}
