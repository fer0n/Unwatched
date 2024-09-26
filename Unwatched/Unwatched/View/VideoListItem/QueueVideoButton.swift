//
//  QueueVideoButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct QueueVideoButton: View {
    @AppStorage(Const.themeColor) var theme = ThemeColor()
    @Environment(\.modelContext) var modelContext

    var video: Video
    var size: CGFloat = 30

    init(_ video: Video, size: CGFloat = 30) {
        self.video = video
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
        _ = VideoService.insertQueueEntries(
            at: 1,
            videos: [video],
            modelContext: modelContext
        )
    }
}
