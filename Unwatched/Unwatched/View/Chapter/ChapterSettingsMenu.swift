//
//  ChapterSettingsMenu.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct ChapterSettingsMenu: View {
    @Environment(AppNotificationVM.self) var appNotificationVM
    @Environment(\.dismiss) var dismiss
    @State var viewModel = GenerateChaptersButtonViewModel()

    /// The video being shown, which is not always the one playing.
    let video: Video?

    /// Leaving this out leaves the transcript actions out with it.
    var transcriptVM: TranscriptView.ViewModel?

    var body: some View {
        Menu {
            transcriptSection

            chapterSection

            Section {
                CloudAiButton(dismissOnPaywall: true) {
                    Text("cloudAI")
                    Text("shortcut")
                    Image(systemName: "sparkles")
                }
                GenerateChaptersMenuButton(viewModel: $viewModel, video: video)

            } header: {
                Text(verbatim: "\(String(localized: "generateChapters")) ✪")
            }
            .tint(Color.automaticBlack)
            .containsPremium()

        } label: {
            Image(systemName: "gearshape.fill")
                .symbolEffect(.rotate, isActive: isWorking)
            Text(showsTranscriptActions ? "settings" : "chapters")
        }
        .overlay {
            ProgressSweep(progress: progress, isFadingOut: isFadingOutProgress)
        }
        .foregroundStyle(Color.automaticBlack)
        #if !os(visionOS)
        .tint(Color.insetBackgroundColor)
        #endif
        .menuOrder(.fixed)
        #if os(macOS)
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.insetBackgroundColor, in: .capsule)
        #elseif os(visionOS)
        .buttonStyle(.bordered)
        .tint(nil)
        .foregroundStyle(.primary)
        #else
        .buttonStyle(.borderedProminent)
        #endif
        .frame(maxWidth: .infinity, alignment: .center)
        .task(id: viewModel.errorMessage) {
            if let message = viewModel.errorMessage {
                appNotificationVM.show(message, isError: true)
            }
        }
    }

    /// The chapters the video came with, and the way back to them after an edit.
    @ViewBuilder
    var chapterSection: some View {
        Section {
            if video?.hasCustomChapterOrder == true {
                videoButton("resetChapterOrder", systemImage: "arrow.up.arrow.down") {
                    ChapterService.resetChapterOrder(for: $0)
                }
            }

            videoButton("restoreChapters", systemImage: "arrow.uturn.backward") {
                ChapterService.restoreChapters(for: $0)
            }
        } header: {
            Text("chapters")
        }
    }

    /// A show that inserts ads publishes the transcript of the ad-free cut, which drifts out of sync with
    /// what plays — so transcribing the audio is worth offering even when a transcript is already there.
    @ViewBuilder
    var transcriptSection: some View {
        if let video, let transcriptVM, showsTranscriptActions {
            Section {
                Button {
                    guard guardPremium(onInteraction: { dismiss() }) else { return }
                    Signal.log("Transcript.Generate", parameters: ["source": "menu"])
                    transcriptVM.generateTranscript(for: video, force: true)
                } label: {
                    Label("generateTranscript", systemImage: "text.quote")
                }
                .disabled(transcriptVM.isGenerating)
                .containsPremium()

                if showsRestore {
                    Button {
                        Signal.log("Transcript.RestorePublished")
                        transcriptVM.restorePublishedTranscript(for: video)
                    } label: {
                        Label("restoreOriginalTranscript", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(transcriptVM.isRestoring)
                }
            } header: {
                Text("transcript")
            }
            .tint(Color.automaticBlack)
        }
    }

    var showsRestore: Bool {
        transcriptVM?.origin == .generated
    }

    /// Read from the progress itself rather than an is-running flag, which drops before the sweep
    /// has finished running out.
    var progress: Double {
        max(viewModel.sweepProgress, transcriptVM?.sweepProgress ?? 0)
    }

    var isFadingOutProgress: Bool {
        viewModel.isFadingOutProgress || transcriptVM?.isFadingOutProgress == true
    }

    var isWorking: Bool {
        viewModel.isLoading || transcriptVM?.isGenerating == true
    }

    var showsTranscriptActions: Bool {
        video?.isPodcast == true
            && transcriptVM != nil
            && TranscriptService.canGenerateTranscript
    }

    private func videoButton(
        _ title: LocalizedStringKey,
        systemImage: String,
        action: @escaping (Video) -> Void
    ) -> some View {
        Button {
            guard let video else {
                Log.warning("ChapterSettingsMenu: No video")
                return
            }
            withAnimation {
                action(video)
            }
        } label: {
            Label(title, systemImage: systemImage)
        }
        .tint(Color.automaticBlack)
    }
}

struct GenerateChaptersMenuButton: View {
    @Environment(PlayerManager.self) var player
    @Binding var viewModel: GenerateChaptersButtonViewModel

    let video: Video?

    var body: some View {
        let transcriptUrl = video?.youtubeId == player.video?.youtubeId
            ? player.transcriptUrl
            : nil
        GenerateChaptersButton(
            viewModel: $viewModel,
            video: video,
            transcriptUrl: transcriptUrl,
            )
    }
}

/// A left-to-right sweep drawn over the menu's own capsule, so the button keeps whatever style its
/// platform gives it.
private struct ProgressSweep: View {
    let progress: Double
    let isFadingOut: Bool

    var body: some View {
        GeometryReader { geo in
            Color.white
                .opacity(0.25)
                .frame(width: geo.size.width * progress)
        }
        .opacity(isFadingOut ? 0 : 1)
        .clipShape(Capsule())
        .allowsHitTesting(false)
        .animation(.linear(duration: 0.3), value: progress)
        .animation(.easeOut(duration: 0.4), value: isFadingOut)
    }
}

#Preview {
    ChapterSettingsMenu(video: Video.getDummy())
        .environment(PlayerManager.getDummy())
        .appNotificationOverlay()
}
