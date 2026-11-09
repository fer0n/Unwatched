//
//  PlaylistAddVideosMenu.swift
//  Unwatched
//

import SwiftUI
import OSLog
import UnwatchedShared

struct PlaylistAddVideosMenu: View {
    @Environment(NavigationManager.self) var navManager

    let playlistUrl: URL

    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Menu {
            Button("addAsVideosToQueue", systemImage: "text.insert") {
                add(to: .queue)
            }
            Button("addAsVideosToInbox", systemImage: "tray.and.arrow.down") {
                add(to: .inbox)
            }
        } label: {
            Group {
                if isLoading {
                    ProgressView()
                } else {
                    Image(systemName: "text.badge.plus")
                        .fontWeight(.black)
                }
            }
            .padding(10)
        }
        .accessibilityLabel("addPlaylistVideos")
        .buttonStyle(CapsuleButtonStyle(primary: false))
        .disabled(isLoading)
        .alert(
            errorMessage ?? "",
            isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("ok") { errorMessage = nil }
        }
    }

    private func add(to target: VideoPlacementArea) {
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                let ids = try await VideoService.addForeignUrlsReturningIds([playlistUrl], in: target)
                guard !ids.isEmpty else { return }
                let tab: NavigationTab = target == .inbox ? .inbox : .queue
                navManager.clearNavigationStack(tab)
                navManager.navigateTo(tab)
            } catch {
                Log.error("PlaylistAddVideosMenu: \(error)")
                errorMessage = error.localizedDescription
            }
        }
    }
}
