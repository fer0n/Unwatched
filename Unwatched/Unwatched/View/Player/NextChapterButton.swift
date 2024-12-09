//
//  PreviousChapterButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct NextChapterButton<Content>: View where Content: View {
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
            if player.goToNextChapter() {
                actionToggle.toggle()
            }
        } label: {
            contentImage(
                Image(systemName: Const.nextChapterSF)
            )
            .symbolEffect(.bounce.down, value: actionToggle)
        }
        .help("nextChapter")
        .sensoryFeedback(Const.sensoryFeedback, trigger: actionToggle)
    }
}
