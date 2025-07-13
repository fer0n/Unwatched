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
                    isCurrentVideo: isCurrentVideo
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

        var filteredTranscript: [TranscriptEntry] {
            if text.debounced.isEmpty {
                return transcript ?? []
            } else {
                return (transcript ?? []).filter { $0.text.localizedCaseInsensitiveContains(text.debounced) }
            }
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

            transcript = await TranscriptService.getTranscript(
                from: transcriptUrl,
                youtubeId: youtubeId,
                )
            Log.info("Transcript loaded for \(youtubeId): \(transcript) entries")
            transcriptYoutubeId = youtubeId
        }
    }
}
