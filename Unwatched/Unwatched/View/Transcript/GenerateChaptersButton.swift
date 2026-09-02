//
//  GenerateChaptersButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared
import FoundationModels

@Observable class GenerateChaptersButtonViewModel: ProgressSweeping {
    var isLoading = false
    var errorMessage: String?

    var sweepProgress: Double = 0
    var isFadingOutProgress = false

    var subTitle: String {
        errorMessage ?? (
            isLoading
                ? String(localized: "loading")
                : String(localized: "experimental")
        )
    }

    @MainActor
    func generateChapters(for video: Video?, transcriptUrl: String?) {
        guard let video else {
            return
        }
        Task {
            if errorMessage != nil {
                errorMessage = nil
            }
            isLoading = true
            sweepProgress = 0
            isFadingOutProgress = false
            defer {
                isLoading = false
            }
            let task = TranscriptService.generateAiChapters(
                for: video,
                transcriptUrl: transcriptUrl
            ) { [weak self] fraction in
                Task { @MainActor in
                    self?.sweepProgress = fraction
                }
            }
            do {
                try await task.value
                await finishProgress()
            } catch LanguageModelSession.GenerationError.guardrailViolation(let context) {
                errorMessage = context.debugDescription
            } catch TranscriptError.noUrl {
                errorMessage = String(localized: "startToLoadTranscript")
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct GenerateChaptersButton: View {
    @Environment(\.dismiss) var dismiss
    @Binding var viewModel: GenerateChaptersButtonViewModel

    var video: Video?
    var transcriptUrl: String?

    private let model = SystemLanguageModel.default

    var body: some View {
        if model.availability == .available {
            generateChaptersButton
                .task(id: video?.youtubeId) {
                    viewModel.errorMessage = nil
                }
        }
    }

    var generateChaptersButton: some View {
        Button {
            let canAccess = guardPremium {
                dismiss()
            }
            if canAccess {
                Signal.log("Chapter.Generate", parameters: ["source": "button"])
                viewModel.generateChapters(for: video, transcriptUrl: transcriptUrl)
            }
        } label: {
            Text("withAppleIntelligence")
            Text(viewModel.subTitle)
            Image(systemName: viewModel.isLoading ? "progress.indicator" : "apple.intelligence")
        }
        .disabled(viewModel.isLoading || video == nil)
    }

}

#Preview {
    GenerateChaptersButton(viewModel: .constant(GenerateChaptersButtonViewModel()), video: nil, transcriptUrl: nil)
        .appNotificationOverlay()
}
