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

    @State var hapticToggle = false

    var videoData: VideoData
    var size: CGFloat = 30
    var onChange: ((_ reason: VideoChangeReason?, _ order: Int?) -> Void)?

    init(
        _ videoData: VideoData,
        size: CGFloat = 30,
        onChange: ((_ reason: VideoChangeReason?, _ order: Int?) -> Void)? = nil
    ) {
        self.videoData = videoData
        self.size = size
        self.onChange = onChange
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
        .buttonStyle(.plain)
        .onTapGesture(perform: addToTopQueue)
        .accessibilityLabel("queueNext")
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
        // button for accessibility, tapGesture to override parent
    }

    func addToTopQueue() {
        guard let video = VideoService.getVideoModel(
            from: videoData,
            modelContext: modelContext
        ) else {
            Log.error("addToTopQueue: no video")
            return
        }
        hapticToggle.toggle()
        VideoService.insertQueueEntries(
            at: 1,
            videos: [video],
            modelContext: modelContext
        )
        // reason: nil so status-driven list refreshes (e.g. search) update without
        // triggering list-specific move/remove handling (Inbox/Queue guard on nil).
        onChange?(nil, nil)
    }
}
