//
//  MenuView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog

struct MenuView: View {
    @Environment(RefreshManager.self) var refresher
    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) var navManager

    @AppStorage(Const.showTabBarLabels) var showTabBarLabels: Bool = true
    @AppStorage(Const.hasNewInboxItems) var hasNewInboxItems: Bool = false
    @AppStorage(Const.hasNewQueueItems) var hasNewQueueItems: Bool = false
    @AppStorage(Const.showTabBarBadge) var showTabBarBadge: Bool = true
    @AppStorage(Const.browserAsTab) var browserAsTab: Bool = false

    @Query(animation: .default) var inbox: [InboxEntry]

    var showCancelButton: Bool = false

    var body: some View {
        @Bindable var navManager = navManager

        let tabs: [TabRoute] =
            [
                TabRoute(
                    view: AnyView(QueueView(showCancelButton: showCancelButton)),
                    image: Image(systemName: Const.queueTagSF),
                    text: "queue",
                    tag: NavigationTab.queue,
                    showBadge: showTabBarBadge && hasNewQueueItems
                ),
                TabRoute(
                    view: AnyView(InboxView(showCancelButton: showCancelButton)),
                    image: getInboxSymbol,
                    text: "inbox",
                    tag: NavigationTab.inbox,
                    showBadge: showTabBarBadge && hasNewInboxItems
                ),
                TabRoute(
                    view: AnyView(LibraryView(showCancelButton: showCancelButton)),
                    image: Image(systemName: "books.vertical"),
                    text: "library",
                    tag: NavigationTab.library
                ),
                TabRoute(
                    view: AnyView(BrowserView(
                        url: $navManager.openTabBrowserUrl,
                        showHeader: false,
                        safeArea: false
                    )),
                    image: Image(systemName: "globe.desk"),
                    text: "browserShort",
                    tag: NavigationTab.browser,
                    show: browserAsTab
                )
            ]

        ScrollViewReader { proxy in
            TabView(selection: $navManager.tab.onUpdate { newValue in
                handleTabChanged(newValue, proxy)
            }) {
                ForEach(tabs, id: \.tag) { tab in
                    if tab.show {
                        TabItemView(tab: tab)
                    }
                }
            }
        }
        .sheet(item: $navManager.openBrowserUrl) { browserUrl in
            BrowserView(startUrl: browserUrl)
        }
    }

    @MainActor
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

    func markVideoWatched(video: Video) {
        _ = VideoService.markVideoWatched(
            video, modelContext: modelContext
        )
    }

    func handleTabChanged(_ newTab: NavigationTab, _ proxy: ScrollViewProxy) {
        Logger.log.info("handleTabChanged \(newTab.rawValue)")
        if newTab == navManager.tab {
            withAnimation {
                let isTopView = navManager.handleTappedTwice()
                if isTopView {
                    proxy.scrollTo(navManager.topListItemId, anchor: .bottom)
                }
            }
        }
        if newTab == .inbox {
            UserDefaults.standard.set(false, forKey: Const.hasNewInboxItems)
        } else if newTab == .queue {
            UserDefaults.standard.set(false, forKey: Const.hasNewQueueItems)
        }
    }
}

#Preview {
    MenuView()
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager.getDummy())
        .environment(RefreshManager())
        .environment(Alerter())
        .environment(PlayerManager())
}
