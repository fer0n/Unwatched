//
//  MenuView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog
import UnwatchedShared

struct MenuView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(RefreshManager.self) var refresher
    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) var navManager
    @Environment(PlayerManager.self) var player

    @AppStorage(Const.showTabBarLabels) var showTabBarLabels = true
    @AppStorage(Const.newQueueItemsCount) var newQueueItemsCount: Int = 0
    @AppStorage(Const.showTabBarBadge) var showTabBarBadge = true
    @AppStorage(Const.browserAsTab) var browserAsTab = false

    var showCancelButton = false
    var showTabBar = true
    var isSidebar = false

    var shouldShowCancelButton: Bool {
        if showCancelButton, #unavailable(iOS 18.1) {
            return true
        }
        return false
    }

    var body: some View {
        @Bindable var navManager = navManager

        ScrollViewReader { proxy in
            TabView(selection: $navManager.tab.onUpdate { newValue in
                handleTabChanged(newValue, proxy)
            }) {
                TabItemView(image: Image(systemName: Const.queueTagSF),
                            tag: NavigationTab.queue,
                            showBadge: showTabBarBadge && newQueueItemsCount > 0) {
                    QueueView(showCancelButton: shouldShowCancelButton)
                }

                InboxTabItemView(showCancelButton: shouldShowCancelButton,
                                 showBadge: showTabBarBadge)

                TabItemView(image: Image(systemName: "books.vertical"),
                            tag: NavigationTab.library) {
                    LibraryView(showCancelButton: shouldShowCancelButton)
                }

                TabItemView(image: Image(systemName: Const.appBrowserSF),
                            tag: NavigationTab.browser,
                            show: browserAsTab) {
                    BrowserView(
                        refresher: refresher,
                        url: $navManager.openTabBrowserUrl,
                        showHeader: false,
                        safeArea: false,
                        dropAreaLeft: isSidebar
                    )
                }
            }
            .setTabViewStyle()
            .sheet(item: $navManager.videoDetail) { video in
                ChapterDescriptionView(video: video)
                    .presentationDragIndicator(.hidden)
                    .environment(\.colorScheme, colorScheme)
                    .environment(player)
                    .environment(navManager)
            }
            .environment(\.horizontalSizeClass, .compact)
            .environment(\.scrollViewProxy, proxy)
        }
        .browserViewSheet(navManager: $navManager)
        .background {
            Color.backgroundColor.ignoresSafeArea(.all)
        }
        .setTabBarAppearance(disableScrollAppearance: isSidebar)
    }

    @MainActor
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
            UserDefaults.standard.set(0, forKey: Const.newInboxItemsCount)
        } else if newTab == .queue {
            UserDefaults.standard.set(0, forKey: Const.newQueueItemsCount)
        }
    }
}

extension TabView {
    @MainActor @ViewBuilder
    /// Workaround: avoid tab view items in title bar on Mac
    func setTabViewStyle() -> some View {
        if #available(iOS 18.0, *), UIDevice.isMac {
            self.tabViewStyle(.sidebarAdaptable)
        } else {
            self
        }
    }
}

#Preview {
    MenuView(showCancelButton: false)
        .modelContainer(DataProvider.previewContainer)
        .environment(NavigationManager.getDummy())
        .environment(RefreshManager())
        .environment(Alerter())
        .environment(PlayerManager())
        .environment(ImageCacheManager())
}
