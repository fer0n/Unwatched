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
    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) var navManager

    @AppStorage(Const.showTabBarLabels) var showTabBarLabels = true
    @AppStorage(Const.newQueueItemsCount) var newQueueItemsCount: Int = 0
    @AppStorage(Const.showTabBarBadge) var showTabBarBadge = true
    @AppStorage(Const.browserAsTab) var browserAsTab = false

    #if os(macOS)
    @AppStorage(Const.videoListFormat) var videoListFormat: VideoListFormat = .compact
    #endif

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
                        .padding(.horizontal, -padding)
                }

                InboxTabItemView(
                    showCancelButton: shouldShowCancelButton,
                    showBadge: showTabBarBadge,
                    horizontalpadding: -padding
                )

                TabItemView(image: Image(systemName: "books.vertical"),
                            tag: NavigationTab.library) {
                    LibraryView(showCancelButton: shouldShowCancelButton)
                        .padding(.horizontal, -padding)
                }

                TabItemView(image: Image(systemName: Const.appBrowserSF),
                            tag: NavigationTab.browser,
                            show: browserAsTab) {
                    BrowserView(
                        url: $navManager.openTabBrowserUrl,
                        showHeader: false,
                        safeArea: false
                    )
                    .padding(.horizontal, -padding)
                }
            }
            .padding(.horizontal, padding)
            .sheet(item: $navManager.videoDetail) { video in
                ChapterDescriptionView(video: video)
                    .presentationDragIndicator(.hidden)
                    .environment(\.colorScheme, colorScheme)
            }
            .environment(\.horizontalSizeClass, .compact)
            .environment(\.scrollViewProxy, proxy)
        }
        #if os(macOS)
        .id(videoListFormat == .compact) // workaround: expansive thumbnail size when switching setting
        #endif
        .browserViewSheet(navManager: $navManager)
        .background {
            Color.backgroundColor.ignoresSafeArea(.all)
        }
        #if os(iOS)
        .setTabBarAppearance(disableScrollAppearance: isSidebar)
        #endif
    }

    @MainActor
    func handleTabChanged(_ newTab: NavigationTab, _ proxy: ScrollViewProxy) {
        Logger.log.info("handleTabChanged \(newTab.rawValue)")
        if newTab == navManager.tab {
            Task { @MainActor in
                withAnimation {
                    let isTopView = navManager.handleTappedTwice()
                    if isTopView {
                        proxy.scrollTo(navManager.topListItemId, anchor: .bottom)
                    }
                }
            }
        }
        if newTab == .inbox {
            UserDefaults.standard.set(0, forKey: Const.newInboxItemsCount)
        } else if newTab == .queue {
            UserDefaults.standard.set(0, forKey: Const.newQueueItemsCount)
        }
    }

    var padding: CGFloat {
        #if os(macOS)
        15
        #else
        0
        #endif
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
