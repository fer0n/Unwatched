//
//  MoveQueueEntry.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct MoveQueueEntry<Content: DynamicViewContent>: DynamicViewContent {
    @Environment(\.modelContext) var modelContext
    @Environment(PlayerManager.self) private var player

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .onMove(perform: moveQueueEntry)
    }

    var data: Content.Data { content.data }

    func moveQueueEntry(from source: IndexSet, to destination: Int) {
        if source.count == 1 && source.first == destination {
            return
        }
        VideoService.moveQueueEntry(from: source,
                                    to: destination,
                                    updateIsNew: true,
                                    modelContext: modelContext)
        if destination == 0 || source.contains(0) {
            player.loadTopmostVideoFromQueue()
        }
    }
}

extension DynamicViewContent {
    @MainActor
    func moveQueueEntryModifier() -> some DynamicViewContent {
        MoveQueueEntry {
            self
        }
    }
}
