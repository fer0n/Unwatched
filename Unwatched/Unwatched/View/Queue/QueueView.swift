//
//  QueueView.swift
//  Unwatched

import SwiftUI
import SwiftData
import OSLog
import UnwatchedShared

struct QueueView: View {
    @Environment(NavigationManager.self) private var navManager
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Tag.order) private var tags: [Tag]
    @State private var showAll = false
    var showCancelButton: Bool = false

    var selectedTag: Tag? {
        navManager.queueTag.tag(in: tags)
    }

    var title: LocalizedStringKey {
        switch navManager.queueTag {
        case .all: "queue"
        case .tag: selectedTag.map { .verbatim($0.name) } ?? "queue"
        }
    }

    var body: some View {
        QueueListView(
            filter: QueueFilter(navManager.queueTag, tags),
            title: title,
            tag: selectedTag,
            showAll: $showAll,
            showCancelButton: showCancelButton
        )
        // a tag deleted on another device leaves the selection pointing at nothing
        .onChange(of: tags, initial: true) {
            if navManager.queueTag.tagId != nil && selectedTag == nil {
                navManager.queueTag = .all
            }
        }
    }
}
