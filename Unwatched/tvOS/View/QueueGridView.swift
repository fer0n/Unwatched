//
//  QueueView.swift
//  UnwatchedTV
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct QueueGridView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \QueueEntry.order, animation: .default) var queue: [QueueEntry]
    @FocusState private var focusedVideo: QueueEntry?
    @State private var showAlert = false

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
            .alert("youtubeAppRequired", isPresented: $showAlert) {
                Button("cancel", role: .cancel) { }
                Button("openAppStore") {
                    guard let url = URL(string: "https://apps.apple.com/app/id544007664") else {
                        print("YouTube App Store URL not working")
                        return
                    }
                    UIApplication.shared.open(
                        url,
                        options: [:],
                        completionHandler: nil
                    )
                }
            }
        }
    }

    func openYouTube(_ id: String) {
        guard let appURL = URL(string: "youtube://watch/\(id)") else {
            print("Invalid YouTube URL: \(id)")
            return
        }
        if UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL, options: [:], completionHandler: nil)
        } else {
            showAlert = true
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
    QueueGridView()
        .modelContainer(DataProvider.previewContainerFilled)
        .environment(ImageCacheManager())
        .environment(SyncManager())
}
