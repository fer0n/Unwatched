//
//  QueueGrid.swift
//  UnwatchedTV
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct QueueGrid: View {
    @Query private var queue: [QueueEntry]
    @FocusState private var focusedVideo: QueueEntry?

    let isFiltered: Bool
    let tagMenu: QueueTagMenu?
    let openYouTube: (String?) async -> Bool
    let playInApp: (Video) -> Void

    let width: Double = 380

    init(
        filter: QueueFilter,
        tagMenu: QueueTagMenu?,
        openYouTube: @escaping (String?) async -> Bool,
        playInApp: @escaping (Video) -> Void
    ) {
        // Not animated: sync imports re-diffing every item made focus stutter on older Apple TVs
        _queue = Query(filter.descriptor())
        self.isFiltered = filter.isActive
        self.tagMenu = tagMenu
        self.openYouTube = openYouTube
        self.playInApp = playInApp
    }

    var body: some View {
        if queue.isEmpty && isFiltered {
            VStack(spacing: 40) {
                tagMenu
                ContentUnavailableView {
                    Label("noQueueItemsInTag", systemImage: "tag")
                } description: {
                    Text("noQueueItemsInTagDescription")
                }
            }
        } else if queue.isEmpty {
            EmptyQueueView()
        } else {
            grid
        }
    }

    private var grid: some View {
        ScrollView {
            HStack {
                tagMenu
                Spacer()
                SyncStatusLabel()
                    .font(.caption)
            }
            .padding(.horizontal, 30)
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
                        playInApp: playInApp,
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
