//
//  FaqView.swift
//  Unwatched
//

import SwiftUI

struct FaqView: View {

    let faqContent: [(question: String, answer: String)] = [
        (
            String(localized: "syncNotWorkingFaqQ"),
            String(localized: "syncNotWorkingFaqA")
        ),
        (
            String(localized: "pictureInPictureFaqQ"),
            String(localized: "pictureInPictureFaqA")
        ),
        (
            String(localized: "durationMissingFaqQ"),
            String(localized: "durationMissingFaqA")
        ),
        (
            String(localized: "watchHistoryNotShowingFaqQ"),
            String(localized: "watchHistoryNotShowingFaqA")
        ),
        (
            String(localized: "morePlatformsFaqQ"),
            String(localized: "morePlatformsFaqA")
        ),
        (
            String(localized: "likeSubscribeVideoFaqQ"),
            String(localized: "likeSubscribeVideoFaqA")
        ),
        (
            String(localized: "blockingAdsFaqQ"),
            String(localized: "blockingAdsFaqA")
        ),
        (
            String(localized: "playerShowsWebsiteFaqQ"),
            String(localized: "playerShowsWebsiteFaqA")
        ),
        (
            String(localized: "fasterSpeedsFaqQ"),
            String(localized: "fasterSpeedsFaqA")
        ),
        (
            String(localized: "morePlaylistsFaqQ"),
            String(localized: "morePlaylistsFaqA")
        )
    ]

    var body: some View {
        ZStack {
            Color.backgroundColor.ignoresSafeArea(.all)

            MyForm {
                ForEach(faqContent, id: \.question) { faq in
                    DisclosureGroup(faq.question) {
                        Text(LocalizedStringKey(faq.answer))
                            .padding(.vertical, 5)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 5)
                }
                .listRowBackground(Color.insetBackgroundColor)
            }
            .listStyle(InsetGroupedListStyle())
            .myNavigationTitle("faq")
        }
    }
}

#Preview {
    FaqView()
}
