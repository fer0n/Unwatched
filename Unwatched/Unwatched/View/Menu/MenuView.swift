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
    @AppStorage(Const.browserDisplayMode) var browserDisplayMode: BrowserDisplayMode = .asSheet

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
                    showCancelButton: showCancelButton,
                    showBadge: showTabBarBadge
                )

                InboxTabItemView(
                    showCancelButton: showCancelButton,
                    showBadge: showTabBarBadge
                )

                LibraryView(showCancelButton: shouldShowCancelButton)
                    .tabItemView(image: Image(systemName: "books.vertical"), tag: NavigationTab.library)

                BrowserView(
                    showHeader: !Device.isMac,
                    safeArea: false
                )
                .tabItemView(
                    image: Image(systemName: Const.youtubeSF),
                    tag: NavigationTab.browser,
                    show: browserDisplayMode == .asTab
                )
            }
            #if os(iOS)
            .apply {
                if #available(iOS 26.0, *) {
                    $0.scrollEdgeEffectHidden(for: .bottom)
                } else {
                    $0
                }
            }
            #endif
            #if os(macOS)
            .popover(isPresented: showVideoDetail) {
                Group {
                    if let video = navManager.videoDetail {
                        videoDetailContent(video)
                    }
                }
            }
            #elseif os(visionOS)
            .sheet(isPresented: showVideoDetail) {
            Group {
            if let video = navManager.videoDetail {
            NavigationStack {
            videoDetailContent(video)
            .toolbar {
            ToolbarItem(placement: .cancellationAction) {
            DismissSheetButton()
            }
            }
            }
            }
            }
            }
            #else
            .sheet(isPresented: showVideoDetail) {
            Group {
            if let video = navManager.videoDetail {
            videoDetailContent(video)
            }
            }
            }
            #endif
            .environment(\.horizontalSizeClass, .compact)
            .environment(\.scrollViewProxy, proxy)
        }
        #if os(macOS)
        .id(videoListFormat == .compact) // workaround: expansive thumbnail size when switching setting
        #endif
        .browserViewSheet(navManager: $navManager)
        .premiumOfferSheet()
        .background {
            (Const.macOS26 || Device.isVision
                ? Color.clear
                : Color.backgroundColor)
                .ignoresSafeArea(.all)
        }
        #if os(iOS)
        .setTabBarAppearance(disableScrollAppearance: isSidebar)
        #endif
    }

    func videoDetailContent(_ video: Video) -> some View {
        ZStack {
            MyBackgroundColor(macOS: false)
            ChapterDescriptionView(video: video, isTransparent: Device.isVision)
                .presentationDragIndicator(.hidden)
        }
        .environment(\.colorScheme, colorScheme)
        .appNotificationOverlay(topPadding: 10)
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

    var showVideoDetail: Binding<Bool> {
        Binding<Bool>(
            get: { navManager.videoDetail != nil },
            set: { isPresented in
                if !isPresented {
                    navManager.videoDetail = nil
                }
            }
        )
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
