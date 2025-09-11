//
//  GenerateChaptersButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared
import FoundationModels

@Observable class GenerateChaptersButtonViewModel {
    var isLoading = false
    var errorMessage: String?

    var subTitle: String {
        errorMessage ?? (
            isLoading
                ? String(localized: "loading")
                : String(localized: "experimental")
        )
    }

    @MainActor @available(iOS 26.0, macOS 26.0, *)
    func generateChapters(for video: Video?, transcriptUrl: String?) {
        guard let video else {
            return
        }
        Task {
            if errorMessage != nil {
                errorMessage = nil
            }
            isLoading = true
            defer {
                isLoading = false
            }
            let task = TranscriptService.generateAiChapters(
                for: video,
                transcriptUrl: transcriptUrl
            ) { _ in }
            do {
                try await task.value
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

@available(iOS 26.0, macOS 26.0, *)
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
    @Previewable @State var appNotificationVM = AppNotificationVM()
    if #available (iOS 26.0, macOS 26.0, *) {
        GenerateChaptersButton(viewModel: .constant(GenerateChaptersButtonViewModel()), video: nil, transcriptUrl: nil)
            .appNotificationOverlay($appNotificationVM)

    }
}
