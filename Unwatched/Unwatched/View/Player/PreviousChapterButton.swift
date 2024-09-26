//
//  PreviousChapterButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PreviousChapterButton<Content>: View where Content: View {
    @Environment(PlayerManager.self) var player
    @State var actionToggle: Bool = false

    private let contentImage: ((Image) -> Content)

    init(
        @ViewBuilder content: @escaping (Image) -> Content = { $0 }
    ) {
        self.contentImage = content
    }

    var body: some View {
        Button {
            actionToggle.toggle()
            player.goToPreviousChapter()
        } label: {
            contentImage(
                Image(systemName: Const.previousChapterSF)
            )
            .symbolEffect(.bounce.down, value: actionToggle)
        }
        .accessibilityLabel("previousChapter")
        .sensoryFeedback(Const.sensoryFeedback, trigger: actionToggle)
    }
}
