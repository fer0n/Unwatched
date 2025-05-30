//
//  FaqView.swift
//  Unwatched
//

import SwiftUI
import UniformTypeIdentifiers

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
            "durationMissingFaqT",
            "durationMissingFaqQ",
            "durationMissingFaqA"
        ),
        FaqInfo(
            "duplicatesFaqT",
            "duplicatesFaqQ",
            "duplicatesFaqA"
        ),
        FaqInfo(
            "overlayStuckFaqT",
            "overlayStuckFaqQ",
            "overlayStuckFaqA"
        ),
        FaqInfo(
            "tvOsFaqT",
            "tvOsFaqQ",
            "tvOsFaqA"
        ),
        FaqInfo(
            "watchHistoryNotShowingFaqT",
            "watchHistoryNotShowingFaqQ",
            "watchHistoryNotShowingFaqA"
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

            #if os(iOS)
            disclosureView(faq)
            #else
            listView(faq)
            #endif
        }
        .listRowBackground(Color.insetBackgroundColor)
    }

    func disclosureView(_ faq: FaqInfo) -> some View {
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
        .contextMenu {
            Button("copyAnswer") {
                copyFaqAnswer(faq.answer)
            }
        }
        .padding(.vertical, 5)
    }

    func listView(_ faq: FaqInfo) -> some View {
        VStack(alignment: .leading) {
            Text(faq.question)
                .bold()
            Text(faq.answer)
                .padding(.vertical, 1)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 15)
    }

    func copyFaqAnswer(_ value: LocalizedStringKey) {
        let value = value.stringValue()
        ClipboardService.set(value)
    }
}

#Preview {
    FaqView()
}
