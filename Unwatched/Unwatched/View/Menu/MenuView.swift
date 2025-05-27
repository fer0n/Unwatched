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
                QueueTabItemView(
                    showCancelButton: shouldShowCancelButton,
                    showBadge: showTabBarBadge,
                    horizontalpadding: -padding
                )

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
            .popover(item: $navManager.videoDetail) { video in
                ZStack {
                    Color.backgroundColor.ignoresSafeArea(.all)

                    ChapterDescriptionView(video: video)
                        .presentationDragIndicator(.hidden)
                }
                .environment(\.colorScheme, colorScheme)
                .presentationCompactAdaptation(
                    Device.isMac ? .popover : .sheet
                )
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
        Log.info("handleTabChanged \(newTab.rawValue)")
        if newTab == navManager.tab {
            let isTopView = navManager.handleTappedTwice()
            Task { @MainActor in
                withAnimation {
                    if isTopView {
                        proxy.scrollTo(navManager.topListItemId, anchor: .bottom)
                    }
                }
            }
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
