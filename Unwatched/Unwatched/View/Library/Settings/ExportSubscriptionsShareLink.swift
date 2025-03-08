//
//  ExportSubscriptionsShareLink.swift
//  Unwatched
//

import SwiftUI

struct ExportSubscriptionsShareLink<Content: View>: View {
    let content: () -> Content

    @State var isExportingAll = false

    var body: some View {
        let feedUrls = AsyncSharableUrls(
            getUrls: exportAllSubscriptions,
            isLoading: $isExportingAll
        )
        ShareLink(item: feedUrls, preview: SharePreview("exportSubscriptions")) {
            if isExportingAll {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                content()
            }
        }
    }

    func exportAllSubscriptions() async -> [(title: String, link: URL?)] {
        let result = try? await SubscriptionService.getAllFeedUrls()
        return result ?? []
    }
}
