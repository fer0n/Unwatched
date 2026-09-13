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
    @Environment(NavigationManager.self) var navManager

    var body: some View {
        @Bindable var navManager = navManager

        tabs
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
        MenuTabBar()
            .ignoresSafeArea()
        #else
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

                Tab(value: NavigationTab.search, role: .search) {
                    SearchView()
                }
            }
            .environment(\.scrollViewProxy, proxy)
        }
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

    #if !os(iOS)
    @MainActor
    func handleTabChanged(_ newTab: NavigationTab, _ proxy: ScrollViewProxy) {
        Log.info("handleTabChanged \(newTab.rawValue)")
        if newTab == navManager.tab {
            let isTopView = navManager.handleTappedTwice()
            #if os(visionOS)
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
            #if os(macOS)
            if navManager.searchTabShouldAutoFocus {
                navManager.pendingSearchFocus = true
            }
            #endif
        }
    }
    #endif

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
    MenuView()
        .modelContainer(DataProvider.previewContainer)
        .environment(NavigationManager.getDummy())
        .environment(RefreshManager())
        .environment(Alerter())
        .environment(PlayerManager())
        .environment(ImageCacheManager())
}
