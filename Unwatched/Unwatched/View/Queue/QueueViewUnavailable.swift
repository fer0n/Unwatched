//
//  QueueViewUnavailable.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct QueueViewUnavailable: View {
    @AppStorage(Const.themeColor) var theme = ThemeColor()
    @Environment(NavigationManager.self) private var navManager

    /// An empty tag looks like an empty queue, so the way out is offered here too.
    var isFiltered: Bool = false
    var tag: Tag?

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(isFiltered ? "noQueueItemsInTag" : "noQueueItems")
            } icon: {
                // different symbols have different intrinsic sizes at the same point size;
                // a fixed frame keeps the icon visually consistent across tags
                Image(systemName: tag?.displaySymbol ?? "rectangle.stack.badge.play.fill")
                    .font(.system(size: 56))
                    .frame(width: 56, height: 56)
                    .contentTransition(.symbolEffect(.replace))
            }
        } description: {
            Text(isFiltered ? "noQueueItemsInTagDescription" : "noQueueItemsDescription")
        } actions: {
            Group {
                if isFiltered {
                    Button {
                        withAnimation {
                            navManager.queueTag = .all
                        }
                    } label: {
                        Text("allVideos")
                            .padding(.horizontal, 8)
                    }
                } else {
                    Button {
                        navManager.presentedSearch.removeAll()
                        navManager.navigateTo(.search)
                        navManager.pendingSearchFocus = true
                        Signal.log("Onboarding.BrowseYoutube")
                    } label: {
                        Text("browser")
                            .padding(.horizontal, 8)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .bold()
            .foregroundStyle(theme.contrastColor)
            .tint(theme.color)
        }
        .contentShape(Rectangle())
        .handleVideoUrlDrop(.queue)
    }
}
