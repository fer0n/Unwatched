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

    var body: some View {
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
        .task(id: refreshId) {
            await viewModel.handleTranscriptLoading(
                youtubeId,
                transcriptUrl
            )
        }

        if viewModel.transcript?.isEmpty != false {
            Text(transcriptStatus)
                .italic()
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            Spacer()
                .frame(height: 300)
        } else {
            LazyVStack(alignment: .leading, spacing: 0) {
                TranscriptList(
                    transcript: viewModel.filteredTranscript,
                    isCurrentVideo: isCurrentVideo,
                    isSearching: !viewModel.text.debounced.isEmpty
                )
            }
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
