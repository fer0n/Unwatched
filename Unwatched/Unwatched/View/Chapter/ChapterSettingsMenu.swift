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

    let video: Video?

    /// The episode the transcript actions apply to, which is the one being shown rather than the one playing.
    /// `nil` leaves those actions out entirely.
    var transcriptVideo: Video?
    var transcriptVM: TranscriptView.ViewModel?

    var body: some View {
        Menu {
            transcriptSection

            if video?.hasCustomChapterOrder == true {
                videoButton("resetChapterOrder", systemImage: "arrow.up.arrow.down") {
                    ChapterService.resetChapterOrder(for: $0)
                }
            }

            videoButton("restoreChapters", systemImage: "arrow.uturn.backward") {
                ChapterService.restoreChapters(for: $0)
            }

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
                .symbolEffect(.rotate, isActive: viewModel.isLoading)
            Text(showsTranscriptActions ? "settings" : "chapters")
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

    /// A show that inserts ads publishes the transcript of the ad-free cut, which drifts out of sync with
    /// what plays — so transcribing the audio is worth offering even when a transcript is already there.
    @ViewBuilder
    var transcriptSection: some View {
        if let transcriptVideo, let transcriptVM, showsTranscriptActions,
           showsRegenerate || showsRestore {
            Section {
                if showsRegenerate {
                    Button {
                        guard guardPremium(onInteraction: { dismiss() }) else { return }
                        Signal.log("Transcript.Generate", parameters: ["source": "menu"])
                        transcriptVM.generateTranscript(for: transcriptVideo, force: true)
                    } label: {
                        Label("generateTranscript", systemImage: "text.quote")
                    }
                    .disabled(transcriptVM.isGenerating)
                }

                if showsRestore {
                    Button {
                        Signal.log("Transcript.RestorePublished")
                        transcriptVM.restorePublishedTranscript(for: transcriptVideo)
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

    var showsRegenerate: Bool {
        transcriptVM?.transcript?.isEmpty == false
    }

    var showsRestore: Bool {
        transcriptVM?.origin == .generated
    }

    var showsTranscriptActions: Bool {
        transcriptVideo?.isPodcast == true
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

struct CloudAiButton<Label: View>: View {
    @Environment(PlayerManager.self) var player
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL

    var dismissOnPaywall: Bool = false
    @ViewBuilder var label: () -> Label

    var body: some View {
        Button {
            let hasAccess = guardPremium(onInteraction: dismissOnPaywall ? { dismiss() } : nil)
            guard hasAccess else { return }

            let name = "Generate Chapters"
            var components = URLComponents()
            let enablePip = !player.pipEnabled && player.isPlaying

            var successUrl = "unwatched://shortcut-success"
            var errorUrl = "unwatched://shortcut-error"

            if enablePip {
                successUrl += "?disablePip=true"
                errorUrl += "?disablePip=true"
            }

            components.scheme = "shortcuts"
            components.host = "x-callback-url"
            components.path = "/run-shortcut"
            components.queryItems = [
                URLQueryItem(name: "name", value: name),
                URLQueryItem(name: "x-success", value: successUrl),
                URLQueryItem(name: "x-error", value: errorUrl)
            ]
            if let url = components.url {
                if enablePip {
                    player.setPip(true)
                    Task {
                        try await Task.sleep(for: .seconds(0.2))
                        openURL(url)
                    }
                } else {
                    openURL(url)
                }
            } else {
                openURL(UrlService.generateChaptersShortcutUrl)
            }
        } label: {
            label()
        }
    }
}

#Preview {
    ChapterSettingsMenu(video: Video.getDummy())
        .environment(PlayerManager.getDummy())
        .appNotificationOverlay()
}
