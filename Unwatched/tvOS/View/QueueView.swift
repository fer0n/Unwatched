//
//  QueueView.swift
//  UnwatchedTV
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct QueueView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \QueueEntry.order, animation: .default) var queue: [QueueEntry]
    @FocusState private var focusedVideo: QueueEntry?

    let width: Double = 380

    var body: some View {
        if queue.isEmpty {
            EmptyQueueView()
        } else {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(
                        .adaptive(
                            minimum: width + 10
                        )
                    )],
                    alignment: .center,
                    spacing: 10
                ) {
                    ForEach(queue) { entry in
                        QueueEntryListItem(
                            entry,
                            width: width,
                            openYouTube: openYouTube,
                            beforeRemove: beforeRemove
                        )
                        .focused($focusedVideo, equals: entry)
                        .padding()
                    }
                }
                .padding()
            }
            .onAppear {
                if focusedVideo == nil,
                   let firstEntry = queue.first {
                    focusedVideo = firstEntry
                }
            }
        }
    }

    func openYouTube(_ id: String) {
        if let url = URL(string: "youtube://watch/\(id)") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    func beforeRemove(_ entry: QueueEntry) {
        if let currentIndex = queue.firstIndex(of: entry) {
            let nextIndex = queue.index(after: currentIndex)
            if nextIndex < queue.endIndex {
                focusedVideo = queue[nextIndex]
            } else {
                let previousIndex = queue.index(before: currentIndex)
                if previousIndex >= queue.startIndex {
                    focusedVideo = queue[previousIndex]
                } else {
                    focusedVideo = nil
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
