//
//  Untitled.swift
//  UnwatchedTV
//

import SwiftUI
import UnwatchedShared

struct QueueEntryListItem: View {
    @Environment(\.modelContext) var modelContext
    var entry: QueueEntry
    let width: Double

    var openYouTube: (String) -> Void
    var beforeRemove: (QueueEntry) -> Void

    @State var toBeWatched: Video?
    @State var toBeCleared: Video?

    init(
        _ entry: QueueEntry,
        width: Double,
        openYouTube: @escaping (String) -> Void,
        beforeRemove: @escaping (QueueEntry) -> Void
    ) {
        self.entry = entry
        self.width = width
        self.openYouTube = openYouTube
        self.beforeRemove = beforeRemove
    }

    var body: some View {
        ZStack {
            if let video = entry.video {
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
                    VideoListItem(video: video, width: width)
                } primaryAction: {
                    openYouTube(video.youtubeId)
                }
                .buttonStyle(FocusButtonStyle())
            } else {
                ZStack {
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
                    ProgressView()
                }
            }
        }
        .task(id: toBeWatched) {
            await handleTask(for: toBeWatched, action: markWatched)
        }
        .task(id: toBeCleared) {
            await handleTask(for: toBeCleared, action: clearVideo)
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
            VideoService.markVideoWatched(video, modelContext: modelContext)
        }
    }

    func clearVideo(_ video: Video) {
        withAnimation {
            beforeRemove(entry)
            VideoService.clearEntries(
                from: video,
                updateCleared: false,
                modelContext: modelContext
            )
        }
    }
}

#Preview {
    QueueView()
        .modelContainer(DataController.previewContainerFilled)
        .environment(ImageCacheManager())
        .environment(SyncManager())
}
