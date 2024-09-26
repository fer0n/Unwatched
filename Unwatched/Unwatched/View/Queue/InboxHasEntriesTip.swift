//
//  InboxHasEntriesTip.swift
//  Unwatched
//

import Foundation
import TipKit
import SwiftData
import UnwatchedShared

struct InboxHasEntriesTip: View {
    @Query(animation: .default) var inbox: [InboxEntry]
    var inboxTip = InboxHasVideosTip()

    var body: some View {
        let inboxHasEntries = !inbox.isEmpty

        ZStack {
            if inboxHasEntries {
                VStack {
                    Spacer()
                    TipView(inboxTip, arrowEdge: .bottom)
                        .fixedSize()
                }
            }
        }
        .onDisappear {
            if inboxHasEntries {
                inboxTip.invalidate(reason: .actionPerformed)
            }
        }
    }
}
