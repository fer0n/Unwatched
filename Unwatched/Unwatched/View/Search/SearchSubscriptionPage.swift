//
//  SearchSubscriptionPage.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

/// Library matches open the regular detail view; channels and podcasts that aren't added yet get a preview.
struct SearchSubscriptionPage: View {
    let sub: SendableSubscription
    let modelContext: ModelContext

    init(_ sub: SendableSubscription, _ modelContext: ModelContext) {
        self.sub = sub
        self.modelContext = modelContext
    }

    var body: some View {
        ZStack {
            if sub.persistentId != nil {
                SendableSubscriptionDetailView(sub, modelContext)
            } else if sub.isPodcast {
                PodcastPreviewView(sub)
            } else {
                ChannelPreviewView(sub)
            }
        }
        #if !os(visionOS)
        .foregroundStyle(Color.neutralAccentColor)
        #endif
        #if os(macOS)
        .navigationStackWorkaround()
        #endif
    }
}
