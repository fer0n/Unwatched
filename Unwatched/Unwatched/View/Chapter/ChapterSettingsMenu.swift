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
        .tint(Color.insetBackgroundColor)
        .menuOrder(.fixed)
        #if os(macOS)
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.insetBackgroundColor, in: .capsule)
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
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL

    var body: some View {
        Button {
            let hasAccess = guardPremium {
                dismiss()
            }
            guard hasAccess else { return }
            openURL(UrlService.generateChaptersShortcutUrl)
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
