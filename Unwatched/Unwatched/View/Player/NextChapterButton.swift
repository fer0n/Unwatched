//
//  PreviousChapterButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct NextChapterButton<Content>: View where Content: View {
    @Environment(PlayerManager.self) var player
    @State var actionToggle: Bool = false

    let isCircleVariant: Bool
    private let contentImage: ((Image) -> Content)

    init(
        isCircleVariant: Bool = false,
        @ViewBuilder content: @escaping (Image) -> Content = { $0 }
    ) {
        self.isCircleVariant = isCircleVariant
        self.contentImage = content
    }

    var body: some View {
        Button {
            if player.goToNextChapter() {
                actionToggle.toggle()
            }
        } label: {
            contentImage(
                innerImage
            )
            .symbolEffect(.bounce.down, value: actionToggle)
        }
        .sensoryFeedback(Const.sensoryFeedback, trigger: actionToggle)
        .help("nextChapter")
        .accessibilityLabel(String(localized: "nextChapter"))
    }

    var innerImage: Image {
        if isCircleVariant {
            Image("custom.chevron.right.2.circle.fill")
        } else {
            Image(systemName: Const.nextChapterSF)
        }
    }
}
