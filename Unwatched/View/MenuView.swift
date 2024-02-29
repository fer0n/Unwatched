//
//  MenuView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct MenuView: View {
    @Environment(RefreshManager.self) var refresher
    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) var navManager
    @AppStorage(Const.showTabBarLabels) var showTabBarLabels: Bool = true
    @AppStorage(Const.hasNewInboxItems) var hasNewInboxItems: Bool = false
    @AppStorage(Const.showNewInboxBadge) var showNewInboxBadge: Bool = true

    @Query var queue: [QueueEntry]
    @Query(animation: .default) var inbox: [InboxEntry]

    @MainActor
    init() {
        let unselectedItemColor = UIColor.lightGray
        UITabBarItem.appearance().badgeColor = unselectedItemColor
    }

    var getInboxSymbol: Image {
        let isLoading = refresher.isLoading
        let isEmpty = inbox.isEmpty
        let currentTab = navManager.tab == .inbox

        let full = isEmpty ? "" : ".full"
        if !isLoading {
            return Image(systemName: "tray\(full)")
        }

        let fill = currentTab ? ".fill" : ""
        return Image("custom.tray.loading\(fill)")
    }

    var body: some View {
        @Bindable var navManager = navManager

        let tabs: [TabRoute] =
            [
                TabRoute(
                    view: AnyView(QueueView(inboxHasEntries: !inbox.isEmpty)),
                    image: Image(systemName: Const.queueTagSF),
                    text: "queue",
                    tag: Tab.queue
                ),
                TabRoute(
                    view: AnyView(InboxView()),
                    image: getInboxSymbol,
                    text: "inbox",
                    tag: Tab.inbox,
                    showBadge: showNewInboxBadge && hasNewInboxItems && navManager.tab != .inbox
                ),
                TabRoute(
                    view: AnyView(LibraryView()),
                    image: Image(systemName: "books.vertical"),
                    text: "library",
                    tag: Tab.library
                )
            ]

        ScrollViewReader { proxy in
            TabView(selection: $navManager.tab.onUpdate { newValue in
                handleTabChanged(newValue, proxy)
            }) {
                ForEach(tabs, id: \.tag) { tab in
                    tab.view
                        .tabItem {
                            tab.image
                                .environment(\.symbolVariants,
                                             navManager.tab == tab.tag
                                                ? .fill
                                                : .none)
                            if tab.showBadge {
                                Text(verbatim: "●")
                            } else if showTabBarLabels {
                                Text(tab.text)
                            }
                        }
                        .tag(tab.tag)
                }
            }
            .tint(.teal)
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

    func handleTabChanged(_ newTab: Tab, _ proxy: ScrollViewProxy) {
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
    var image: Image
    var text: LocalizedStringKey
    var tag: Tab
    var showBadge: Bool = false
}

#Preview {
    MenuView()
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager.getDummy())
        .environment(RefreshManager())
        .environment(Alerter())
        .environment(PlayerManager())
}
