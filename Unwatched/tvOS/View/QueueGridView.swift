//
//  QueueView.swift
//  UnwatchedTV
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct QueueGridView: View {
    @Query(sort: \Tag.order) private var tags: [Tag]
    @AppStorage(Const.tvSelectedTagName) private var selectedTagName = ""
    @State private var showAlert = false
    /// The video the in-app player is showing. Lives here rather than on the grid item so
    /// marking the video watched — which drops its entry from the queue — can't tear the
    /// player down mid-video.
    @State private var playingVideo: Video?

    private var selectedTag: Tag? {
        tags.first { $0.name == selectedTagName }
    }

    private var selection: Binding<Tag?> {
        Binding(
            get: { selectedTag },
            set: { selectedTagName = $0?.name ?? "" }
        )
    }

    private var filter: QueueFilter {
        QueueFilter(tag: selectedTag, in: tags)
    }

    var body: some View {
        QueueGrid(
            filter: filter,
            tagMenu: tags.isEmpty ? nil : QueueTagMenu(tags: tags, selection: selection),
            openYouTube: openYouTube,
            playInApp: { playingVideo = $0 }
        )
        .id(selectedTag?.persistentModelID)
        // Both presentations sit outside the queue/empty switch: marking the last video
        // watched empties the queue while the player is still on screen.
        .fullScreenCover(item: $playingVideo) { video in
            TvPlayerView(video: video, filter: filter, openYouTube: openYouTube)
        }
        .alert("youtubeAppRequired", isPresented: $showAlert) {
            Button("cancel", role: .cancel) { }
            Button {
                guard let url = URL(string: "https://apps.apple.com/app/id544007664") else {
                    print("YouTube App Store URL not working")
                    return
                }
                UIApplication.shared.open(
                    url,
                    options: [:],
                    completionHandler: nil
                )
            } label: {
                Text(verbatim: "App Store")
            }
        }
    }

    func openYouTube(_ id: String?) async -> Bool {
        guard let id, let appURL = URL(string: "youtube://watch/\(id)") else {
            print("Invalid YouTube URL: \(id ?? "NIL")")
            return false
        }

        let success = await withCheckedContinuation { continuation in
            UIApplication.shared.open(appURL, options: [:]) { success in
                continuation.resume(returning: success)
            }
        }

        if !success {
            await MainActor.run {
                showAlert = true
            }
        }
        return success
    }
}

#Preview {
    QueueGridView()
        .modelContainer(DataProvider.previewContainerFilled)
        .environment(ImageCacheManager())
        .environment(SyncManager())
        .environment(SyncProgress())
}
