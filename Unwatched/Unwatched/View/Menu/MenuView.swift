//
//  MenuView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog
import UnwatchedShared

struct MenuView: View {
    @Environment(NavigationManager.self) var navManager

    var body: some View {
        @Bindable var navManager = navManager

        tabs
            .environment(\.horizontalSizeClass, .compact)
            .browserViewSheet(navManager: $navManager)
            .premiumOfferSheet()
            .background {
                (Const.macOS26 || Device.isVision
                    ? Color.clear
                    : Color.backgroundColor)
                    .ignoresSafeArea(.all)
            }
    }

    @ViewBuilder
    var tabs: some View {
        #if os(iOS)
        if MenuTabBarController.usesProminentPlayButton {
            MenuTabBar()
                .ignoresSafeArea()
        } else {
            // no role: .search here — a search-role tab always renders detached from the
            // others, which only makes sense once the play button takes that treatment instead
            tabView(searchRole: nil)
        }
        #else
        tabView(searchRole: .search)
        #endif
    }

    @ViewBuilder
    func tabView(searchRole: TabRole?) -> some View {
        @Bindable var navManager = navManager

        ScrollViewReader { proxy in
            TabView(selection: $navManager.tab.onUpdate { newValue in
                handleTabChanged(newValue, proxy)
            }) {
                Tab(value: NavigationTab.queue) {
                    QueueTabItemView()
                } label: {
                    QueueTabLabel()
                }

                Tab(value: NavigationTab.inbox) {
                    InboxTabItemView()
                } label: {
                    InboxTabLabel()
                }

                Tab(value: NavigationTab.library) {
                    LibraryView()
                } label: {
                    MenuTabLabel(image: Image(systemName: "books.vertical"), tag: .library)
                }

                if let searchRole {
                    Tab(value: NavigationTab.search, role: searchRole) {
                        SearchView()
                    }
                } else {
                    Tab(value: NavigationTab.search) {
                        SearchView()
                    } label: {
                        MenuTabLabel(image: Image(systemName: "magnifyingglass"), tag: .search)
                    }
                }
            }
            .environment(\.scrollViewProxy, proxy)
        }
    }

    @MainActor
    func handleTabChanged(_ newTab: NavigationTab, _ proxy: ScrollViewProxy) {
        Log.info("handleTabChanged \(newTab.rawValue)")
        if newTab == navManager.tab {
            let isTopView = navManager.handleTappedTwice()
            #if os(visionOS) || os(iOS)
            // Tapping the search tab again asks for a new search; the results page pops on its own.
            if newTab == .search && isTopView {
                navManager.pendingSearchFocus = true
            }
            #endif
            Task { @MainActor in
                withAnimation {
                    if isTopView {
                        proxy.scrollTo(navManager.topListItemId, anchor: .bottom)
                    }
                }
            }
        } else if newTab == .search {
            #if os(macOS) || os(iOS)
            if navManager.searchTabShouldAutoFocus {
                navManager.pendingSearchFocus = true
            }
            #endif
        }
    }
}

#Preview {
    MenuView()
        .modelContainer(DataProvider.previewContainer)
        .environment(NavigationManager.getDummy())
        .environment(RefreshManager())
        .environment(Alerter())
        .environment(PlayerManager())
        .environment(ImageCacheManager())
}
