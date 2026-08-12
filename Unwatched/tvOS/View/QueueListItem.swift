//
//  Untitled.swift
//  UnwatchedTV
//

import SwiftUI
import UnwatchedShared

struct QueueEntryListItem: View {
    @AppStorage(Const.markAsWatched) var markAsWatched: Bool = false
    @AppStorage(Const.tvPlaybackMode) var playbackMode: TvPlaybackMode = .youtubeApp
    @Environment(\.modelContext) var modelContext
    var entry: QueueEntry
    let width: Double

    var openYouTube: (String?) async -> Bool
    var playInApp: (Video) -> Void
    var beforeRemove: (QueueEntry) -> Void

    @State var toBeWatched: Video?
    @State var toBeCleared: Video?

    init(
        _ entry: QueueEntry,
        width: Double,
        openYouTube: @escaping (String?) async -> Bool,
        playInApp: @escaping (Video) -> Void,
        beforeRemove: @escaping (QueueEntry) -> Void
    ) {
        self.entry = entry
        self.width = width
        self.openYouTube = openYouTube
        self.playInApp = playInApp
        self.beforeRemove = beforeRemove
    }

    var body: some View {
        ZStack {
            Menu {
                Button(
                    "markWatched",
                    systemImage: Const.checkmarkSF,
                    action: { toBeWatched = entry.video }
                )
                Button(
                    "clear",
                    systemImage: Const.clearNoFillSF,
                    action: { toBeCleared = entry.video }
                )
            } label: {
                label
            } primaryAction: {
                Task {
                    await handleItemClick(entry.video)
                }
            }
            .buttonStyle(FocusButtonStyle())
        }
        .task(id: toBeWatched) {
            await handleTask(for: toBeWatched, action: markWatched)
        }
        .task(id: toBeCleared) {
            await handleTask(for: toBeCleared, action: clearVideo)
        }
    }

    @ViewBuilder
    var label: some View {
        if let video = entry.video {
            VideoGridItem(video: video, width: width)
        } else {
            VStack {
                ThumbnailPlaceholder(width)
                    .aspectRatio(contentMode: .fill)
                    .frame(
                        width: width,
                        height: width / (16/9)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 35))
                    .aspectRatio(contentMode: .fit)

                Text(verbatim: "\n\n")
            }
        }
    }

    private func handleItemClick(_ video: Video?) async {
        guard let video else { return }
        switch playbackMode {
        case .inApp:
            // The player marks the video watched itself: it knows when playback actually
            // started, and how far it got.
            playInApp(video)
        case .youtubeApp:
            let success = await openYouTube(video.youtubeId)
            if markAsWatched && success {
                VideoService.setVideoWatched(video, modelContext: modelContext)
            }
        }
    }

    private func handleTask(for video: Video?, action: @escaping (Video) -> Void) async {
        guard let video = video else {
            return
        }
        try? await Task.sleep(nanoseconds: 700_000_000)
        action(video)
    }

    func markWatched(_ video: Video) {
        withAnimation {
            beforeRemove(entry)
            VideoService.setVideoWatched(video, modelContext: modelContext)
        }
    }

    func clearVideo(_ video: Video) {
        withAnimation {
            beforeRemove(entry)
            VideoService.clearEntries(
                from: video,
                modelContext: modelContext
            )
        }
    }
}

#Preview {
    QueueGridView()
        .modelContainer(DataProvider.previewContainerFilled)
        .environment(ImageCacheManager())
        .environment(SyncManager())
}
