//
//  FaqView.swift
//  Unwatched
//

import SwiftUI

struct FaqInfo {
    var title: LocalizedStringKey
    var question: LocalizedStringKey
    var answer: LocalizedStringKey

    init(_ title: LocalizedStringKey,
         _ question: LocalizedStringKey,
         _ answer: LocalizedStringKey) {
        self.title = title
        self.question = question
        self.answer = answer
    }
}

struct FaqView: View {

    let faqContent: [FaqInfo] = [
        FaqInfo(
            "pictureInPictureFaqT",
            "pictureInPictureFaqQ",
            "pictureInPictureFaqA"
        ),
        FaqInfo(
            "tvOsFaqT",
            "tvOsFaqQ",
            "tvOsFaqA"
        ),
        FaqInfo(
            "durationMissingFaqT",
            "durationMissingFaqQ",
            "durationMissingFaqA"
        ),
        FaqInfo(
            "overlayStuckFaqT",
            "overlayStuckFaqQ",
            "overlayStuckFaqA"
        ),
        FaqInfo(
            "watchHistoryNotShowingFaqT",
            "watchHistoryNotShowingFaqQ",
            "watchHistoryNotShowingFaqA"
        ),
        FaqInfo(
            "duplicatesFaqT",
            "duplicatesFaqQ",
            "duplicatesFaqA"
        ),
        FaqInfo(
            "macOsFaqT",
            "macOsFaqQ",
            "macOsFaqA"
        ),
        FaqInfo(
            "syncNotWorkingFaqT",
            "syncNotWorkingFaqQ",
            "syncNotWorkingFaqA"
        ),
        FaqInfo(
            "likeSubscribeVideoFaqT",
            "likeSubscribeVideoFaqQ",
            "likeSubscribeVideoFaqA"
        ),
        FaqInfo(
            "blockingAdsFaqT",
            "blockingAdsFaqQ",
            "blockingAdsFaqA"
        ),
        FaqInfo(
            "playerShowsWebsiteFaqT",
            "playerShowsWebsiteFaqQ",
            "playerShowsWebsiteFaqA"
        ),
        FaqInfo(
            "morePlaylistsFaqT",
            "morePlaylistsFaqQ",
            "morePlaylistsFaqA"
        )
    ]

    var body: some View {
        ForEach(faqContent.indices, id: \.self) { index in
            let faq = faqContent[index]

            DisclosureGroup(faq.title) {
                VStack(alignment: .leading) {
                    Text(faq.question)
                        .bold()
                    Text(faq.answer)
                        .padding(.vertical, 5)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .padding(.vertical, 5)
        }
        .listRowBackground(Color.insetBackgroundColor)
    }
}

#Preview {
    FaqView()
}
