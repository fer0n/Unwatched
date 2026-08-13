//
//  Untitled.swift
//  UnwatchedTV
//

import SwiftUI
import SwiftData
import OSLog
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
    @State var removeEmptyEntry = false

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
                if entry.video != nil {
                    Button(
                        "markWatched",
                        systemImage: Const.checkmarkSF,
                        action: { toBeWatched = entry.video }
                    )
                }
                Button(
                    "clear",
                    systemImage: Const.clearNoFillSF,
                    action: {
                        if let video = entry.video {
                            toBeCleared = video
                        } else {
                            removeEmptyEntry = true
                        }
                    }
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
        .task(id: removeEmptyEntry) {
            guard removeEmptyEntry else { return }
            try? await Task.sleep(nanoseconds: 700_000_000)
            clearEntry()
        }
        .task {
            reconnectVideo()
        }
    }

    @ViewBuilder
    var label: some View {
        if let video = entry.video {
            VideoGridItem(video: video, width: width)
        } else {
            VStack(alignment: .leading) {
                ThumbnailPlaceholder(width)
                    .aspectRatio(contentMode: .fill)
                    .frame(
                        width: width,
                        height: width / (16/9)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 35))
                    .aspectRatio(contentMode: .fit)

                Text("emptyEntry")
                    .lineLimit(3)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .frame(width: width)
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

    /// Relinks an entry that lost its video relationship in sync, using the youtube id the entry
    /// keeps for exactly that case. Without this the entry stays an untitled black tile on tvOS.
    private func reconnectVideo() {
        guard entry.video == nil, let youtubeId = entry.youtubeId else {
            return
        }
        let fetch = FetchDescriptor<Video>(predicate: #Predicate { $0.youtubeId == youtubeId })
        guard let video = try? modelContext.fetch(fetch).first else {
            Log.info("reconnectVideo: no video for \(youtubeId)")
            return
        }
        guard video.queueEntry == nil else {
            // the video is already queued elsewhere: this entry is a leftover duplicate
            return
        }
        video.queueEntry = entry
        try? modelContext.save()
        Log.info("reconnectVideo: reconnected \(youtubeId)")
    }

    /// Removes an entry that has no video to clear through.
    private func clearEntry() {
        withAnimation {
            beforeRemove(entry)
            VideoService.deleteQueueEntry(entry, modelContext: modelContext)
            try? modelContext.save()
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
