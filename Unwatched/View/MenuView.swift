//
//  MenuView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct MenuView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) private var navManager
    @AppStorage(Const.showTabBarLabels) var showTabBarLabels: Bool = true
    @Query var queue: [QueueEntry]
    @Query(animation: .default) var inbox: [InboxEntry]

    var body: some View {
        @Bindable var navManager = navManager

        let tabs: [TabRoute] =
            [
                TabRoute(
                    view: AnyView(QueueView(inboxHasEntries: !inbox.isEmpty)),
                    image: Const.queueTagSF,
                    text: "queue",
                    tag: Tab.queue
                ),
                TabRoute(
                    view: AnyView(InboxView()),
                    image: inbox.isEmpty ? Const.inboxTabEmptySF : Const.inboxTabFullSF,
                    text: "inbox",
                    tag: Tab.inbox
                ),
                TabRoute(
                    view: AnyView(LibraryView()),
                    image: "books.vertical",
                    text: "library",
                    tag: Tab.library
                )
            ]

        ScrollViewReader { proxy in
            TabView(selection: $navManager.tab.onUpdate { newValue in
                handleSameTabTapped(newValue, proxy)
            }) {
                ForEach(tabs, id: \.tag) { tab in
                    tab.view
                        .tabItem {
                            Image(systemName: tab.image)
                                .environment(\.symbolVariants,
                                             navManager.tab == tab.tag
                                                ? .fill
                                                : .none)
                            if showTabBarLabels {
                                Text(tab.text)
                            }
                        }
                        .tag(tab.tag)
                }
            }
            .environment(navManager)
            .tint(.myAccentColor)
        }
        .sheet(item: $navManager.openBrowserUrl) { browserUrl in
            let url = browserUrl.getUrl
            BrowserView(url: url)
        }
    }

    func markVideoWatched(video: Video) {
        _ = VideoService.markVideoWatched(
            video, modelContext: modelContext
        )
    }

    func handleSameTabTapped(_ newTab: Tab, _ proxy: ScrollViewProxy) {
        if newTab == navManager.tab {
            withAnimation {
                let isTopView = navManager.handleTappedTwice()
                if isTopView {
                    proxy.scrollTo(navManager.topListItemId, anchor: .bottom)
                }
            }
        }
    }
}

struct TabRoute {
    var view: AnyView
    var image: String
    var text: LocalizedStringKey
    var tag: Tab
}

#Preview {
    MenuView()
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager.getDummy())
        .environment(RefreshManager())
        .environment(Alerter())
        .environment(PlayerManager())
}
