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
        if model.availability == .available {
            generateChaptersButton
                .task(id: video?.youtubeId) {
                    errorMessage = nil
                }
        }
    }

    var generateChaptersButton: some View {
        Button {
            generateChapters()
        } label: {
            ZStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text("generateChaptersFromTranscript")
                    Text(errorMessage ?? String(localized: "experimental"))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
                .padding(.horizontal, 15)
                .opacity(isLoading ? 0 : 1)

                Image(systemName: Const.premiumIndicatorSF)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .topTrailing
                    )
                    .padding(5)
                    .opacity(errorMessage == nil ? 1 : 0)

                if isLoading {
                    CircularProgressView(progress: $progress, stops: [0.19, 0.9])
                        .progressViewStyle(.linear)
                        .foregroundStyle(Color.automaticBlack)
                }
            }
            .animation(.default, value: isLoading)
            .animation(.default, value: errorMessage == nil)
            .background(
                RoundedRectangle(cornerRadius: ChapterList.itemRadius)
                    .fill(Color.insetBackgroundColor)
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
