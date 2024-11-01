//
//  UserTipsView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct UserTip {
    var title: LocalizedStringKey
    var message: LocalizedStringKey
    var systemImage: String

    init(_ title: LocalizedStringKey,
         _ message: LocalizedStringKey,
         _ systemImage: String) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
    }
}

struct UserTipsView: View {
    let userTips = [
        UserTip(
            "tipSwipeActions",
            "tipSwipeActionsMessage",
            "hand.draw.fill"
        ),
        UserTip(
            "tipPlaybackSpeed",
            "tipPlaybackSpeedMessage",
            "lock.circle.fill"
        ),
        UserTip(
            "tipChapters",
            "tipChaptersMessage",
            "checkmark.circle.fill"
        ),
        UserTip(
            "tipKeyboardShortcuts",
            "tipKeyboardShortcutsMessage",
            "keyboard.fill"
        )
    ]

    @State var currentPage: Int?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top) {
                    ForEach(userTips.indices, id: \.self) { index in
                        renderUserTip(userTips[index])
                    }
                    .containerRelativeFrame(
                        .horizontal,
                        count: 1,
                        spacing: 0
                    )
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $currentPage, anchor: .leading)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.never)
            .animation(.default, value: currentPage)

            PageControl(currentPage: $currentPage, numberOfPages: userTips.count)
                .padding(10)
        }
    }

    func renderUserTip(_ tip: UserTip) -> some View {
        VStack(alignment: .center) {
            HStack {
                Image(systemName: tip.systemImage)
                    .font(.largeTitle)
                    .opacity(0.5)
                Text(tip.title)
                    .font(.title)
                    .fontWeight(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Text(tip.message)
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    List {
        ZStack {
            UserTipsView()
                .padding(.top)
        }
        .listRowBackground(Color.teal.mix(with: .black, by: 0.4))
        .listRowInsets(EdgeInsets())
        .foregroundStyle(.white)
        // .foregroundStyle(theme.darkContrastColor)
    }
}
