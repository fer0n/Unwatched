//
//  Untitled.swift
//  UnwatchedTV
//

import SwiftUI
import UnwatchedShared

struct QueueEntryListItem: View {
    var entry: QueueEntry
    let width: Double

    var openYouTube: (String) -> Void

    init(_ entry: QueueEntry, width: Double, openYouTube: @escaping (String) -> Void) {
        self.entry = entry
        self.width = width
        self.openYouTube = openYouTube
    }

    var body: some View {
        ZStack {
            if let video = entry.video {
                Button {
                    openYouTube(video.youtubeId)
                } label: {
                    VideoListItem(video: video, width: width)
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
    }
}

#Preview {
    QueueView()
        .modelContainer(DataController.previewContainerFilled)
        .environment(ImageCacheManager())
        .environment(SyncManager())
}
