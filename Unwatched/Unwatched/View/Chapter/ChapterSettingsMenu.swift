//
//  ChapterSettingsMenu.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct ChapterSettingsMenu: View {
    @Environment(AppNotificationVM.self) var appNotificationVM
    @State var viewModel = GenerateChaptersButtonViewModel()

    let video: Video?

    var body: some View {
        Menu {
            Button {
                guard let video else {
                    Log.warning("restoreChapters: No video")
                    return
                }
                withAnimation {
                    ChapterService.restoreChapters(for: video)
                }
            } label: {
                Label("restoreChapters", systemImage: "arrow.uturn.backward")
            }
            .tint(Color.automaticBlack)

            Section {
                CloudAiButton()
                GenerateChaptersMenuButton(viewModel: $viewModel, video: video)

            } header: {
                Text(verbatim: "\(String(localized: "generateChapters")) ✪")
            }
            .tint(Color.automaticBlack)
            .containsPremium()

        } label: {
            Image(systemName: "gearshape.fill")
                .apply {
                    if #available(iOS 18, macOS 15, *) {
                        $0.symbolEffect(.rotate, isActive: viewModel.isLoading)
                    } else {
                        $0.symbolEffect(.pulse, isActive: viewModel.isLoading)
                    }
                }
            Text("chapters")
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
}

struct GenerateChaptersMenuButton: View {
    @Environment(PlayerManager.self) var player
    @Binding var viewModel: GenerateChaptersButtonViewModel

    let video: Video?

    var body: some View {
        let transcriptUrl = video?.youtubeId == player.video?.youtubeId
            ? player.transcriptUrl
            : nil
        if #available(iOS 26, macOS 26.0, *) {
            GenerateChaptersButton(
                viewModel: $viewModel,
                video: video,
                transcriptUrl: transcriptUrl,
                )
        }
    }
}

struct CloudAiButton: View {
    @Environment(PlayerManager.self) var player
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL

    var body: some View {
        Button {
            let hasAccess = guardPremium {
                dismiss()
            }
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
                URLQueryItem(name: "x-error", value: errorUrl),
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
            Text("cloudAI")
            Text("shortcut")
            Image(systemName: "sparkles")
        }
    }
}

#Preview {
    ChapterSettingsMenu(video: Video.getDummy())
        .environment(PlayerManager.getDummy())
        .appNotificationOverlay()
}
