//
//  QueueVideoButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared
import OSLog

struct QueueVideoButton: View {
    @AppStorage(Const.themeColor) var theme = ThemeColor()
    @Environment(\.modelContext) var modelContext

    var videoData: VideoData
    var size: CGFloat = 30

    init(_ videoData: VideoData, size: CGFloat = 30) {
        self.videoData = videoData
        self.size = size
    }

    var body: some View {
        Button(role: .destructive, action: addToTopQueue, label: {
            Image(systemName: "arrow.uturn.right")
                .font(.callout)
                .fontWeight(.bold)
                .frame(width: size, height: size)
                .background {
                    Circle()
                        .fill(.automaticBlack.opacity(0.1))
                }
                .foregroundStyle(.secondary)
        })
        .onTapGesture(perform: addToTopQueue)
        .accessibilityLabel("queueNext")
        // button for accessibility, tapGesture to override parent
    }

    func addToTopQueue() {
        guard let video = VideoService.getVideoModel(
            from: videoData,
            modelContext: modelContext
        ) else {
            Logger.log.error("addToTopQueue: no video")
            return
        }
        _ = VideoService.insertQueueEntries(
            at: 1,
            videos: [video],
            modelContext: modelContext
        )
    }
}
