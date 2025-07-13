//
//  InboxHasEntriesTip.swift
//  Unwatched
//

import Foundation
import TipKit
import SwiftData
import UnwatchedShared

struct InboxHasEntriesTip: View {
    @Query(descriptor, animation: .default) var inbox: [InboxEntry]
    var inboxTip = InboxHasVideosTip()

    var body: some View {
        ZStack {
            if inboxHasEntries {
                TipView(inboxTip, arrowEdge: arrowEdge)
                    .fixedSize()
                    .frame(maxHeight: .infinity, alignment: alignment)
            }
        }
        .onDisappear {
            if inboxHasEntries {
                inboxTip.invalidate(reason: .actionPerformed)
            }
        }
    }

    var alignment: Alignment {
        #if os(macOS)
        .top
        #else
        .bottom
        #endif
    }

    var arrowEdge: Edge {
        #if os(macOS)
        .top
        #else
        .bottom
        #endif
    }

    var inboxHasEntries: Bool {
        !inbox.isEmpty
    }

    static var descriptor: FetchDescriptor<InboxEntry> {
        var descriptor = FetchDescriptor<InboxEntry>()
        descriptor.fetchLimit = 1
        return descriptor
    }
}
