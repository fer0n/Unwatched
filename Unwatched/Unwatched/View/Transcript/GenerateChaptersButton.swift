//
//  GenerateChaptersButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
struct GenerateChaptersButton: View {
    var video: Video?
    var transcriptUrl: String?

    @State var isLoading = false
    @State var progress: Double = 0.05
    @State var errorMessage: String?

    private var model = SystemLanguageModel.default

    init(video: Video? = nil, transcriptUrl: String? = nil) {
        self.video = video
        self.transcriptUrl = transcriptUrl
    }

    var body: some View {
        if #available(iOS 26, *), model.availability == .available {
            generateChaptersButton
        }
    }

    var generateChaptersButton: some View {
        Button {
            generateChapters()
        } label: {
            ZStack {
                VStack(spacing: 0) {
                    Text("generateChaptersFromTranscript")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 10)

                    if let errorMessage {
                        Text(verbatim: errorMessage)
                            .padding([.horizontal, .bottom])
                            .foregroundStyle(.secondary)
                    }
                }
                .opacity(isLoading ? 0 : 1)

                if isLoading {
                    CircularProgressView(progress: $progress, stops: [0.19, 0.9])
                        .progressViewStyle(.linear)
                        .foregroundStyle(Color.automaticBlack)
                }
            }
            .animation(.default, value: isLoading)
            .animation(.default, value: errorMessage == nil)
            .background(
                RoundedRectangle(cornerRadius: ChapterList.itemRadius).fill(Color.insetBackgroundColor)
            )
        }
        .buttonStyle(.plain)
    }

    func generateChapters() {
        guard let video else {
            return
        }
        Task {
            isLoading = true
            progress = 0.0
            defer {
                isLoading = false
            }

            // Provide progress reporting closure when supported by TranscriptService.generateAiChapters
            let task = TranscriptService.generateAiChapters(
                for: video,
                transcriptUrl: transcriptUrl
            ) { value in
                Task { @MainActor in
                    progress = value
                }
            }
            do {
                try await task.value
                if errorMessage != nil {
                    errorMessage = nil
                }
            } catch LanguageModelSession.GenerationError.guardrailViolation(let context) {
                errorMessage = context.debugDescription
            } catch TranscriptError.noUrl {
                errorMessage = String(localized: "startToLoadTranscript")
            } catch {
                errorMessage = error.localizedDescription
            }

            // give the progress some time to complete
            try? await Task.sleep(for: .seconds(0.3))
        }
    }
}
