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
    @AppStorage(Const.sheetOpacity) var sheetOpacity: Bool = false

    @Query(animation: .default) var inbox: [InboxEntry]

    var showCancelButton: Bool = false

    @MainActor
    init(showCancelButton: Bool = false) {
        self.showCancelButton = showCancelButton
        customizeTabBarAppearance()
    }

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
                        container: modelContext.container,
                        refresher: refresher,
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
            BrowserView(container: modelContext.container,
                        refresher: refresher,
                        startUrl: browserUrl)
        }
        .background {
            Color.backgroundColor.ignoresSafeArea(.all)
        }
        .onChange(of: sheetOpacity) {
            customizeTabBarAppearance(reload: true)
        }
    }

    @MainActor
    func customizeTabBarAppearance(reload: Bool = false) {
        let appearance = UITabBarAppearance()
        if sheetOpacity {
            appearance.backgroundColor = UIColor(Color.backgroundColor).withAlphaComponent(Const.sheetOpacityValue)
            UITabBar.appearance().standardAppearance = appearance
        } else {
            appearance.backgroundColor = UIColor(Color.backgroundColor)
            appearance.backgroundImage = nil
            appearance.shadowImage = nil

            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().barTintColor = UIColor(Color.backgroundColor)
            UITabBar.appearance().backgroundImage = UIImage()
            UITabBar.appearance().backgroundColor = UIColor(Color.backgroundColor)
        }
        if reload {
            UIApplication
                .shared
                .connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                .reload()
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
    MenuView(showCancelButton: false)
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager.getDummy())
        .environment(RefreshManager())
        .environment(Alerter())
        .environment(PlayerManager())
}
